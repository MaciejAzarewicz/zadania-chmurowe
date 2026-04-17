#!/usr/bin/env bash
set -euo pipefail

vols=()
if [ $# -gt 0 ]; then
  vols=("$@")
else
  # default: inspect all volumes
  mapfile -t vols < <(docker volume ls -q)
fi

for v in "${vols[@]}"; do
  echo "Volume: $v"
  mountpoint=$(docker volume inspect --format '{{.Mountpoint}}' "$v" 2>/dev/null || echo "(n/a)")
  echo "  Mountpoint: $mountpoint"
  echo -n "  Size: "
  docker run --rm -v "${v}:/data" alpine sh -c "du -sh /data 2>/dev/null || echo '0'"

  echo -n "  Used by containers:"
  used=()
  for cid in $(docker ps -a -q); do
    mounts=$(docker inspect -f '{{range .Mounts}}{{printf "%s\n" .Name}}{{end}}' $cid)
    if echo "$mounts" | grep -q "^${v}$"; then
      used+=("$(docker inspect -f '{{.Name}}' $cid | sed 's#^/##')")
    fi
  done
  if [ ${#used[@]} -eq 0 ]; then
    echo " none"
  else
    echo
    for c in "${used[@]}"; do
      echo "    - $c"
    done
  fi
  echo
done
