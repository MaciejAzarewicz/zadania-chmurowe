#!/bin/sh
set -e
cd "$(dirname "$0")"

docker network create --driver bridge --subnet 172.28.10.0/24 --gateway 172.28.10.1 proxy-net || true
docker network create --driver bridge --subnet 172.28.20.0/24 --gateway 172.28.20.1 app-net || true
docker network create --driver bridge --subnet 172.28.30.0/24 --gateway 172.28.30.1 db-net || true

docker build -t product-backend:lab -f Dockerfile.backend .
docker build -t product-worker:lab -f Dockerfile.worker .

docker run -d --name postgres --network db-net --ip 172.28.30.5 -e POSTGRES_PASSWORD=pass postgres:15
docker run -d --name redis --network app-net --ip 172.28.20.5 redis:7

docker run -d --name backend_1 --network proxy-net --ip 172.28.10.11 --mac-address aa:bb:cc:00:00:11 -e INSTANCE_ID=backend_1 product-backend:lab
docker network connect --ip 172.28.20.11 app-net backend_1
docker network connect --ip 172.28.30.11 db-net backend_1

docker run -d --name backend_2 --network proxy-net --ip 172.28.10.12 --mac-address aa:bb:cc:00:00:12 -e INSTANCE_ID=backend_2 product-backend:lab
docker network connect --ip 172.28.20.12 app-net backend_2
docker network connect --ip 172.28.30.12 db-net backend_2

docker run -d --name worker --network app-net --ip 172.28.20.20 --mac-address aa:bb:cc:00:00:20 -e WORKER=worker product-worker:lab
docker network connect --ip 172.28.30.20 db-net worker

docker run -d --name nginx --network proxy-net --ip 172.28.10.10 --mac-address aa:bb:cc:00:00:10 -p 80:80 -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro nginx:1.25

echo "Networks:"
docker network inspect proxy-net app-net db-net --format '{{json .Containers}}'

echo "Container network info:"
for c in nginx backend_1 backend_2 worker redis postgres; do
  echo "-- $c --"
  docker inspect $c --format '{{json .NetworkSettings.Networks}}'
done

echo "To test load balancing:"
echo "  curl -sS http://localhost/items -H 'Accept: application/json' -I | grep X-Instance || true"
