#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# Usage: ./run_dev.sh [-d]
# -d : run detached (background)

VOLUME_NODE_MODULES="product-dashboard_dev_node_modules"
CONTAINER_NAME="backend-dev"
NETWORK=${NETWORK:-product-net}
PORT=${PORT:-3000}
DETACH=false

while getopts "d" opt; do
  case $opt in
    d) DETACH=true ;;
  esac
done

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "Creating docker network $NETWORK"
  docker network create "$NETWORK"
fi

if ! docker volume inspect "$VOLUME_NODE_MODULES" >/dev/null 2>&1; then
  docker volume create "$VOLUME_NODE_MODULES"
fi

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

# Command executed inside container: ensure nodemon is available, then run it
RUN_CMD="sh -c 'set -e; cd /app; if [ ! -x \"node_modules/.bin/nodemon\" ]; then echo Installing nodemon into /app/node_modules; npm install --no-audit --no-fund nodemon; fi; npx nodemon --legacy-watch --signal SIGINT server.js'"

if [ "$DETACH" = true ]; then
  docker run -d --name "$CONTAINER_NAME" --network "$NETWORK" -p ${PORT}:3000 \
    -v "$ROOT_DIR":/app -v ${VOLUME_NODE_MODULES}:/app/node_modules \
    -e POSTGRES_HOST=postgres -e REDIS_HOST=redis node:18-alpine $RUN_CMD
  echo "Started $CONTAINER_NAME in detached mode. Watch logs with: docker logs -f $CONTAINER_NAME"
else
  docker run --rm --name "$CONTAINER_NAME" --network "$NETWORK" -p ${PORT}:3000 \
    -v "$ROOT_DIR":/app -v ${VOLUME_NODE_MODULES}:/app/node_modules \
    -e POSTGRES_HOST=postgres -e REDIS_HOST=redis node:18-alpine $RUN_CMD
fi

echo "To test auto-reload:"
echo "  1) In another shell: curl http://localhost:${PORT}/api/items"
echo "  2) Edit server.js on the host (change response text in any endpoint)."
echo "  3) Re-run curl — nodemon inside container will reload the process automatically (no docker build needed)."
