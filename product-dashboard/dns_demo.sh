#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p demo_outputs

echo "default-bridge: start two containers on default bridge" > demo_outputs/dns_default.txt
docker run -d --name a alpine:3.18 sh -c "apk add --no-cache iputils >/dev/null 2>&1; sleep 1d"
docker run -d --name b alpine:3.18 sh -c "apk add --no-cache iputils >/dev/null 2>&1; sleep 1d"
sleep 1
docker exec a ping -c 1 b >> demo_outputs/dns_default.txt 2>&1 || true
docker exec a ping -c 1 $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' b) >> demo_outputs/dns_default.txt 2>&1 || true
docker rm -f a b

echo "custom-bridge: create network and start containers" > demo_outputs/dns_custom.txt
docker network create demo-net || true
docker run -d --network demo-net --name a2 alpine:3.18 sh -c "apk add --no-cache iputils >/dev/null 2>&1; sleep 1d"
docker run -d --network demo-net --name b2 alpine:3.18 sh -c "apk add --no-cache iputils >/dev/null 2>&1; sleep 1d"
sleep 1
docker exec a2 ping -c 1 b2 >> demo_outputs/dns_custom.txt 2>&1 || true
docker rm -f a2 b2
docker network rm demo-net

echo "dns demo done. outputs in demo_outputs/"
