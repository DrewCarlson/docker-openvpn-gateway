FROM alpine:latest

RUN apk update && apk add --no-cache openvpn iptables socat curl jq docker-cli

COPY src/discover_services.sh /discover_services.sh
COPY src/start.sh /start.sh

ENV OPENVPN_CONFIG_FILE="/etc/openvpn/openvpn-gateway.ovpn"

CMD ["/start.sh"]