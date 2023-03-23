#!/bin/sh

# Get the OpenVPN container's name
openvpn_container_name=$(cat /etc/hostname)

# Get the network name used by the OpenVPN container
network_name=$(docker inspect --format '{{ range $key, $value := .NetworkSettings.Networks }}{{ $key }}{{ end }}' $openvpn_container_name)

# Function to update the socat rules
update_socat_rules() {
  container_id=$1
  forward_port=$2
  forward_protocol=$3

  # Get the container IP address
  container_ip=$(docker inspect --format "{{ .NetworkSettings.Networks.${network_name}.IPAddress }}" $container_id)

  # Check if a socat process is already running for this container
  socat_pid=$(pgrep -f "socat.*${forward_protocol}-CONNECT:${container_ip}:${forward_port}")

  if [ -z "$socat_pid" ]; then
    echo "[VPN-GATEWAY] Forwarding ${forward_protocol} port $forward_port to container $container_id ($container_ip)"
    socat ${forward_protocol}-LISTEN:$forward_port,reuseaddr,fork,bind=0.0.0.0 ${forward_protocol}-CONNECT:${container_ip}:${forward_port} &
  fi
}

# Function to process containers and setup forwarding rules
process_container() {
  container_id=$1
  container_labels=$(docker inspect --format '{{ json .Config.Labels }}' $container_id)
  forward_configs=$(echo $container_labels | jq -r '.["'"$LABEL_NAME"'"] // empty')
  auto_forward_enabled=$(echo $container_labels | jq -r '.["vpn_gateway.enable"] // "false"')

  if [ ! -z "$forward_configs" ]; then
    # Process each forward config separated by a semicolon
    old_IFS="$IFS"
    IFS=';'
    set -- $forward_configs
    IFS="$old_IFS"

    for forward_config; do
      forward_port=$(echo $forward_config | cut -d ':' -f 1)
      forward_protocol=$(echo $forward_config | cut -d ':' -f 2)
      update_socat_rules $container_id $forward_port $forward_protocol
    done
  elif [ "$auto_forward_enabled" = "true" ]; then
    # Process exposed ports
    exposed_ports=$(docker inspect --format '{{json .Config.ExposedPorts}}' $container_id | jq -r 'keys[]')
    for exposed_port in $exposed_ports; do
      forward_port=$(echo $exposed_port | cut -d '/' -f 1)
      forward_protocol=$(echo $exposed_port | cut -d '/' -f 2)
      update_socat_rules $container_id $forward_port $forward_protocol
    done
  fi
}

# Initial check for existing containers with either label
for container_id in $(docker ps -q -f label=vpn_gateway.enable=true; docker ps -q -f label=$LABEL_NAME); do
  process_container $container_id
done

# Listen for Docker events
(
  docker events --filter label=vpn_gateway.enable=true --format '{{json .}}' &
  docker events --filter label=$LABEL_NAME --format '{{json .}}' &
  wait
) | while read line; do
  # Extract the container ID and event type from the event
  container_id=$(echo $line | jq -r .Actor.ID)
  event_type=$(echo $line | jq -r .Type)
  event_action=$(echo $line | jq -r .Action)

  if [[ "$event_type" != "container" ]]; then
    continue
  fi

  # Update the socat rules based on the event type
  case "$event_action" in
      "create")
        echo "[VPN-GATEWAY] Container $container_id created."
        process_container $container_id
        ;;
      "start")
        echo "[VPN-GATEWAY] Container $container_id started."
        process_container $container_id
        ;;
      "stop")
        echo "[VPN-GATEWAY] Container $container_id stopped."
        for forward_port in $(pgrep -f "socat.*CONNECT:${container_id}"); do
          socat_pid=$(pgrep -f "socat.*CONNECT:.*:${forward_port}")
          echo "Stopping socat process for port $forward_port (PID: $socat_pid)"
          kill $socat_pid
        done
        ;;
      "destroy")
        echo "[VPN-GATEWAY] Container $container_id destroyed."
        for forward_port in $(pgrep -f "socat.*CONNECT:${container_id}"); do
          socat_pid=$(pgrep -f "socat.*CONNECT:.*:${forward_port}")
          echo "Stopping socat process for port $forward_port (PID: $socat_pid)"
          kill $socat_pid
        done
        ;;
    esac
done
