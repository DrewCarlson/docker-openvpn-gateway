# openvpn-gateway

A simple Docker container to make services accessible over a VPN connection.
It uses OpenVPN as the VPN client and socat to port forward.

### Setup

In this example we setup an `openvpn-gateway` enabling access to a Traefik server container

1. Create a `docker-compose.yml` with an `openvpn-gateway` :

```yaml
version: '3.8'
networks:
    openvpn-gateway-network:

services:
    openvpn-gateway:
        image: /* image name, e.g., my-registry/vpn-gateway:latest */
        volumes:
            - /* path to your OpenVPN configuration file */:/etc/openvpn/your_openvpn_config.ovpn
            - /var/run/docker.sock:/var/run/docker.sock
        cap_add:
            - NET_ADMIN
        networks:
            - openvpn-gateway-network

    traefik:
        image: traefik:v2.5
        labels:
            - "com.example.vpn-forward.80=80"
            - "com.example.vpn-forward.443=443"
        networks:
            - openvpn-gateway-network
```

2. Start the `openvpn-gateway` and Traefik containers:
```
docker-compose up -d
```

5. Verify that you can access Traefik at the VPN's public IP address.

### Advanced

For more advanced usage, you can use environment variables to configure the `openvpn-gateway` container. The following variables are available:

- `FORWARD_PORTS`: A comma-separated list of container names and ports to be forwarded over the VPN. Example: `FORWARD_PORTS=traefik:80,traefik:443`
- `OPENVPN_CONFIG_FILE`: The path to the OpenVPN configuration file. Default: `OPENVPN_CONFIG_FILE=/etc/openvpn/openvpn-gateway.ovpn`
- `OPENVPN_USERNAME`: The username for the OpenVPN connection (if required).
- `OPENVPN_PASSWORD`: The password for the OpenVPN connection (if required).
- `OPENVPN_OPTS`: Additional options to pass to the OpenVPN client. Example: `OPENVPN_OPTS="--route-delay 2 --ping-restart 0"`

### License

This project is licensed under the MIT License. See the `LICENSE` file for details.
