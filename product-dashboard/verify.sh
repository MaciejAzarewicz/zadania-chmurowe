#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p demo_outputs

echo "1. Network inspect" > demo_outputs/network_inspect.txt
docker network inspect proxy-net app-net db-net >> demo_outputs/network_inspect.txt 2>&1 || true

echo "2. backend_1 can ping postgres" > demo_outputs/backend_ping_postgres.txt
docker exec backend_1 ping -c 3 postgres >> demo_outputs/backend_ping_postgres.txt 2>&1 || true

echo "3. nginx cannot ping postgres" > demo_outputs/nginx_ping_postgres.txt
docker exec nginx ping -c 3 postgres >> demo_outputs/nginx_ping_postgres.txt 2>&1 || true

echo "4. curl X-Instance" > demo_outputs/loadbalancer_instances.txt
for i in 1 2 3 4 5; do curl -sI http://localhost/items | grep -i X-Instance || true; done >> demo_outputs/loadbalancer_instances.txt 2>&1 || true

echo "5. Inspect static IPs and MACs" > demo_outputs/inspect_containers.txt
for c in nginx backend_1 backend_2 worker redis postgres; do
  echo "---- $c ----" >> demo_outputs/inspect_containers.txt
  docker inspect $c --format '{{json .NetworkSettings.Networks}}' >> demo_outputs/inspect_containers.txt 2>&1 || true
done

echo "6. Demonstrate host network" > demo_outputs/host_network.txt
docker run --rm --network host --name hostdemo alpine:3.18 sh -c "apk add --no-cache curl >/dev/null 2>&1 || true; curl -sI http://localhost:80 || true" >> demo_outputs/host_network.txt 2>&1 || true

echo "7. Demonstrate none network" > demo_outputs/none_network.txt
docker run --rm --network none --name nonedemo alpine:3.18 sh -c "ip addr" >> demo_outputs/none_network.txt 2>&1 || true

echo "verify done. outputs in demo_outputs/"
