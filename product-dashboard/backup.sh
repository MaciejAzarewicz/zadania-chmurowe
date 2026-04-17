#!/usr/bin/env bash
set -euo pipefail

VOLUME=${1:-pgdata}
OUTDIR=${2:-$(pwd)/backups}
mkdir -p "$OUTDIR"
TS=$(date +%Y%m%d%H%M%S)
OUTFILE_NAME="${VOLUME}-${TS}.tar.gz"
OUTFILE_PATH="$OUTDIR/$OUTFILE_NAME"

echo "Creating backup of volume '$VOLUME' -> $OUTFILE_PATH"
docker run --rm -v "${VOLUME}:/volume" -v "${OUTDIR}:/backups" alpine \
  sh -c "tar czf /backups/${OUTFILE_NAME} -C /volume ."

echo "Backup saved: $OUTFILE_PATH"
