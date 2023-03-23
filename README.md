# docker-openvpn-gateway

Make Docker services available over a VPN connection's dedicated IP using OpenVPN and socat.

## Usage

To use `openvpn-gateway` requires the following:

1. Create a network for the VPN container and relevant services to use

CLI:
```sh
docker network create openvpn_gateway_network
```

docker-compose.yml:
```sh
networks:
    openvpn-gateway-network:
```

2. Create the `openvpn-gateway` service:

CLI:
```sh
docker run -d \
    --name openvpn-gateway \
    --network openvpn-gateway-network \
    --cap-add NET_ADMIN \
    --device /dev/net/tun \
    -v /path/to/openvpn.conf:/etc/openvpn/openvpn-gateway.ovpn \
    -v /var/run/docker.sock:/var/run/docker.sock \
    ghcr.io/drewcarlson/docker-openvpn-gateway:latest
```

docker-compose.yml:
```yaml
services:
    openvpn-gateway:
        image: ghcr.io/drewcarlson/docker-openvpn-gateway:latest
        volumes:
            - /path/to/openvpn.conf:/etc/openvpn/openvpn-gateway.ovpn
            - /var/run/docker.sock:/var/run/docker.sock
        cap_add:
            - NET_ADMIN
        devices:
            - /dev/net/tun
        networks:
            - openvpn-gateway-network
```

3. Specify what services/ports to route:

To configure your container, you must attach the container to the `openvpn-gateway-network` and specify one of the following labels:

`openvpn_gateway.auto=true`: Automatically route to exposed ports
`openvpn_gateway.forward=80:TCP;443:TCP`: Route only specific Ports/Protocols as `PORT:PROTOCOL`, separating multiple ports with `;`


## Example

In this example we setup an `openvpn-gateway` service to make a Traefik container available.

1. Create a `docker-compose.yml` with an `openvpn-gateway`:

```yaml
version: '3.8'
networks:
    openvpn-gateway-network:

services:
    openvpn-gateway:
        image: ghcr.io/drewcarlson/docker-openvpn-gateway:latest
        volumes:
            - /* path of openvpn config file */:/etc/openvpn/openvpn-gateway.ovpn
            - /var/run/docker.sock:/var/run/docker.sock
        cap_add:
            - NET_ADMIN
        devices:
            - /dev/net/tun
        networks:
            - openvpn-gateway-network

    traefik:
        image: traefik:v2.5
        labels:
            - "openvpn_gateway.auto=true"
        ports:
            - 80
            - 443
        networks:
            - openvpn-gateway-network
            - default
```

2. Start the `openvpn-gateway` and Traefik containers:
```
docker-compose up -d
```

Traefik is now available from the VPN's public IP address.

## Additional Configuration

The following environment variables are available to further configure `openvpn-gateway`:

- `OPENVPN_CONFIG_FILE`: The path to the OpenVPN configuration file. Default: `/etc/openvpn/openvpn-gateway.ovpn`
- `OPENVPN_USERNAME`: The username for the OpenVPN connection (if required).
- `OPENVPN_PASSWORD`: The password for the OpenVPN connection (if required).
- `OPENVPN_OPTS`: Additional options to pass to the OpenVPN client. Example: `OPENVPN_OPTS="--route-delay 2 --ping-restart 0"`

## License

This project is licensed under the Apache 2.0 License. See the [`LICENSE`](LICENSE) file for details.
