#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "Starting local registry (localhost:5000)..."
docker rm -f registry >/dev/null 2>&1 || true
docker run -d --name registry -p 5000:5000 registry:2

echo "Ensuring buildx builder exists and is used..."
if ! docker buildx inspect multi-builder >/dev/null 2>&1; then
  docker buildx create --name multi-builder --use
else
  docker buildx use multi-builder
fi

echo "Building and pushing backend:v2 (linux/amd64,linux/arm64) to localhost:5000..."
docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.backend -t localhost:5000/product-dashboard-backend:v2 product-dashboard --push

echo "Building and pushing frontend:v2 (linux/amd64,linux/arm64) to localhost:5000..."
docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.frontend -t localhost:5000/product-dashboard-frontend:v2 product-dashboard --push

echo "Inspecting pushed images..."
echo "--- backend imagetools inspect ---"
docker buildx imagetools inspect localhost:5000/product-dashboard-backend:v2 | tee imagetools-backend-v2.txt
echo "--- frontend imagetools inspect ---"
docker buildx imagetools inspect localhost:5000/product-dashboard-frontend:v2 | tee imagetools-frontend-v2.txt

echo "Done. Inspect files: imagetools-backend-v2.txt, imagetools-frontend-v2.txt"
