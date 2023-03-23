#!/bin/sh

set -e

# Check if OpenVPN config file exists
if [ ! -f "$OPENVPN_CONFIG_FILE" ]; then
  echo "[OVPN-GATEWAY] Error: OpenVPN config file not found: $OPENVPN_CONFIG_FILE"
  exit 1
fi

# Configure NAT for VPN connection
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

# Start service discovery script in the background
/discover_services.sh &

# Set OpenVPN credentials from environment variables
echo "$OPENVPN_USERNAME" > /etc/openvpn/auth.txt
echo "$OPENVPN_PASSWORD" >> /etc/openvpn/auth.txt

# Start OpenVPN
echo "[OVPN-GATEWAY] Starting OpenVPN with config $OPENVPN_CONFIG_FILE"
openvpn --log-append /dev/stdout --config $OPENVPN_CONFIG_FILE --daemon $OPENVPN_OPTS

# Wait for OpenVPN to start
counter=0
while ! pgrep -x "openvpn" > /dev/null; do
  counter=$((counter + 1))
  if [ $counter -gt 30 ]; then
    echo "[OVPN-GATEWAY] Error: OpenVPN failed to start"
    exit 1
  fi
  sleep 1
done

tail -f /dev/null