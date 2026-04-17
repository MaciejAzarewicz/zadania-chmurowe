#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <backup-archive> [volume-name]"
  exit 1
fi

BACKUP_FILE="$1"
VOLUME=${2:-pgdata}

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 2
fi

OUTDIR="$(cd "$(dirname "$BACKUP_FILE")" && pwd)"
BASE="$(basename "$BACKUP_FILE")"

echo "Stopping containers that use volume '$VOLUME' (if any)..."
stopped=()
for cid in $(docker ps -a -q); do
  mounts=$(docker inspect -f '{{range .Mounts}}{{printf "%s\n" .Name}}{{end}}' $cid)
  if echo "$mounts" | grep -q "^${VOLUME}$"; then
    name=$(docker inspect -f '{{.Name}}' $cid | sed 's#^/##')
    echo "  stopping $name ($cid)"
    docker stop $cid >/dev/null || true
    stopped+=($cid)
  fi
done

echo "Restoring archive $BASE -> volume $VOLUME"
docker run --rm -v "${VOLUME}:/volume" -v "${OUTDIR}:/backups" alpine \
  sh -c "tar xzf /backups/${BASE} -C /volume"

echo "Starting temporary postgres to verify DB availability..."
docker rm -f postgres-restore-test >/dev/null 2>&1 || true
docker run -d --name postgres-restore-test -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -e POSTGRES_DB=products \
  -v "${VOLUME}:/var/lib/postgresql/data" postgres:15-alpine >/dev/null

echo "Waiting for postgres to become ready (timeout 60s)..."
ready=false
for i in $(seq 1 60); do
  if docker exec postgres-restore-test pg_isready -U postgres >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done

if [ "$ready" = true ]; then
  echo "Postgres is ready. Restore verified."
  docker rm -f postgres-restore-test >/dev/null 2>&1 || true
else
  echo "Postgres did not become ready within timeout. Check container logs: docker logs postgres-restore-test"
  docker rm -f postgres-restore-test >/dev/null 2>&1 || true
  exit 3
fi

if [ ${#stopped[@]} -gt 0 ]; then
  echo "Restarting previously stopped containers..."
  for cid in "${stopped[@]}"; do
    docker start $cid >/dev/null || true
  done
fi

echo "Restore process complete."
