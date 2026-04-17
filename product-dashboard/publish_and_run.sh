#!/usr/bin/env bash
set -euo pipefail

# Usage: ./publish_and_run.sh
# This script builds multi-arch images (v2 + latest), pushes them to Docker Hub,
# pulls them back, creates network and runs containers (api-a, api-b, frontend),
# then performs basic endpoint checks.

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

DOCKER_USER="${DOCKER_USER:-maciejazarewicz}"
BACKEND_IMAGE="$DOCKER_USER/backend"
FRONTEND_IMAGE="$DOCKER_USER/frontend"
BUILDER="${BUILDER:-multiarch}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

echo "1) Log in to Docker Hub (if not already):"
echo "   docker login"
docker login

echo "2) Create and bootstrap buildx builder:"
docker buildx create --name "$BUILDER" --use || docker buildx use "$BUILDER"
docker buildx inspect --bootstrap

echo "3) Build & push backend (multi-arch)"
docker buildx build --builder "$BUILDER" --platform $PLATFORMS \
  -f Dockerfile.backend \
  -t ${BACKEND_IMAGE}:v2 \
  -t ${BACKEND_IMAGE}:latest \
  --push .

echo "4) Build & push frontend (multi-arch)"
docker buildx build --builder "$BUILDER" --platform $PLATFORMS \
  -f Dockerfile.frontend \
  -t ${FRONTEND_IMAGE}:v2 \
  -t ${FRONTEND_IMAGE}:latest \
  --push .

echo "5) Inspect manifests (multi-arch):"
docker buildx imagetools inspect ${BACKEND_IMAGE}:latest | tee imagetools-backend-latest.txt
docker buildx imagetools inspect ${FRONTEND_IMAGE}:latest | tee imagetools-frontend-latest.txt

echo "6) Remove local tags (optional, to ensure pulls come from remote):"
docker rmi ${BACKEND_IMAGE}:v2 ${BACKEND_IMAGE}:latest || true
docker rmi ${FRONTEND_IMAGE}:v2 ${FRONTEND_IMAGE}:latest || true

echo "7) Pull images from registry:
"docker pull ${BACKEND_IMAGE}:latest"
docker pull ${BACKEND_IMAGE}:latest
docker pull ${FRONTEND_IMAGE}:latest

echo "8) Prepare network and remove any old containers"
docker network create app-net >/dev/null 2>&1 || true
docker rm -f api-a api-b frontend >/dev/null 2>&1 || true

echo "9) Run two backend instances"
docker run -d --name api-a --network app-net -e INSTANCE_ID=api-a ${BACKEND_IMAGE}:latest
docker run -d --name api-b --network app-net -e INSTANCE_ID=api-b ${BACKEND_IMAGE}:latest

echo "10) Run frontend (nginx)"
docker run -d --name frontend --network app-net -p 8080:8080 ${FRONTEND_IMAGE}:latest

echo "Waiting a few seconds for services to start..."
sleep 5

echo "11) Basic tests (human-friendly):"
echo "  curl http://localhost:8080/"
curl -fsS http://localhost:8080/ || echo "frontend not reachable"

echo "  curl http://localhost:8080/api/items"
curl -fsS http://localhost:8080/api/items || echo "items endpoint not reachable"

echo "  POST an item"
curl -fsS -X POST http://localhost:8080/api/items -H "Content-Type: application/json" -d '{"name":"test"}' || echo "post failed"

echo "  curl http://localhost:8080/api/stats"
curl -fsS http://localhost:8080/api/stats || echo "stats endpoint not reachable"

echo "  check cache header (X-Cache)"
curl -i -s http://localhost:8080/api/stats | sed -n '1,20p'

echo "12) Run backend-health container for /health on host port 3001"
docker rm -f backend-health >/dev/null 2>&1 || true
docker run -d --name backend-health --network app-net -p 3001:3000 ${BACKEND_IMAGE}:latest
sleep 2
curl -fsS http://localhost:3001/health || echo "health endpoint not reachable"

echo "All done. Inspect imagetools output files: imagetools-backend-latest.txt, imagetools-frontend-latest.txt"
