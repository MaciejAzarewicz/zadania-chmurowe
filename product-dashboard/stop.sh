#!/bin/sh
set -e
cd "$(dirname "$0")"

for c in nginx backend_1 backend_2 worker redis postgres; do
  docker rm -f $c 2>/dev/null || true
done

docker network rm proxy-net app-net db-net 2>/dev/null || true
