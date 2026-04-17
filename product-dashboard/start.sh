#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "Building images for local run..."
docker build -f Dockerfile.backend -t product-dashboard-backend:local .
docker build -f Dockerfile.frontend -t product-dashboard-frontend:local .

echo "Creating network and volumes..."
docker network inspect product-net >/dev/null 2>&1 || docker network create product-net
docker volume inspect pgdata >/dev/null 2>&1 || docker volume create pgdata

echo "Starting Postgres (named volume: pgdata)..."
docker rm -f postgres >/dev/null 2>&1 || true
docker run -d \
  --name postgres \
  --network product-net \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=products \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:15-alpine

echo "Starting Redis (tmpfs for /data)..."
docker rm -f redis >/dev/null 2>&1 || true
docker run -d \
  --name redis \
  --network product-net \
  --tmpfs /data:rw,size=64m \
  -p 6379:6379 \
  redis:7-alpine \
  redis-server --save "" --appendonly no

echo "Starting backend instances (api-a, api-b)..."
docker rm -f api-a api-b >/dev/null 2>&1 || true
docker run -d --name api-a --network product-net -e POSTGRES_HOST=postgres -e REDIS_HOST=redis product-dashboard-backend:local
docker run -d --name api-b --network product-net -e POSTGRES_HOST=postgres -e REDIS_HOST=redis product-dashboard-backend:local

echo "Starting frontend (nginx) with bind mount for nginx.conf..."
docker rm -f frontend >/dev/null 2>&1 || true
docker run -d --name frontend --network product-net -p 8080:8080 \
  -v "$ROOT_DIR/nginx.conf":/etc/nginx/nginx.conf:ro \
  product-dashboard-frontend:local

echo "All services started. Frontend available at http://localhost:8080"

echo "Example: Add item -> curl -X POST http://localhost:8080/api/items -H 'Content-Type: application/json' -d '{\"name\":\"test\"}'"
