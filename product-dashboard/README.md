Setup and verification

Run:

```sh
./start.sh
```

This creates three networks: `proxy-net`, `app-net`, `db-net` with gateways, builds images, and runs containers with static IPs and some custom MAC addresses.

Checks to perform after start:

- `docker network inspect proxy-net app-net db-net` to see assigned containers.
- `docker exec backend_1 ping -c 3 postgres` should succeed.
- `docker exec nginx ping -c 3 postgres` should fail (nginx not on db-net).
- `curl -I http://localhost/items` repeat to see alternating `X-Instance` header.

DNS demo:

Default bridge (no DNS):

```sh
docker run --rm --name a alpine:3.18 sh -c "apk add --no-cache iputils && sleep 1d" &
docker run --rm --name b alpine:3.18 sh -c "apk add --no-cache iputils && sleep 1d" &
docker exec a ping -c 1 b || true
docker rm -f a b 2>/dev/null || true
```

Custom bridge (DNS works):

```sh
docker network create custom-net || true
docker run --rm --network custom-net --name a alpine:3.18 sh -c "apk add --no-cache iputils && sleep 1d" &
docker run --rm --network custom-net --name b alpine:3.18 sh -c "apk add --no-cache iputils && sleep 1d" &
docker exec a ping -c 1 b || true
docker rm -f a b 2>/dev/null || true
docker network rm custom-net
```

Host/None demo notes:

- `--network host`: container shares host network; can `ss -tlnp` inside to see host ports.
- `--network none`: container has only loopback; `ip addr` shows `lo` only.
