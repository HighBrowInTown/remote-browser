#!/bin/bash

USER_NAME=${1:-"user-${RANDOM}"}
PASSWORD=${2:-"${RANDOM}"}
BROWSER=${3:-'chrome'}
# Get all ports already used by podman containers
USED_PORTS=$(podman ps -a --format "{{.Ports}}" | awk -F'[:>-]' '{ print $2 }' | sort -n | uniq)

# Find the next available port
LOCAL_PORT="${LOCAL_PORT:-2222}"

for PORT in $USED_PORTS; do
  if [[ "$PORT" -eq "$LOCAL_PORT" ]]; then
    ((LOCAL_PORT++))
  fi
done

# Create a podman container
podman run -d \
  --name="${BROWSER}-${RANDOM}" \
  --security-opt seccomp=unconfined \
  --security-opt apparmor=unconfined \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Kolkata \
  -e CUSTOM_USER="${USER_NAME}" \
  -e PASSWORD="${PASSWORD}" \
  -e CHROME_CLI=--no-sandbox \
  -p "${LOCAL_PORT}":3001 \
  --shm-size="2gb" \
  --memory="4g" \
  --cpus="2.0" \
  --restart unless-stopped \
  lscr.io/linuxserver/"${BROWSER}":latest

echo "{USER: ${USER_NAME}, PASS: ${PASSWORD}, BROWSER: ${BROWSER}, PORT: ${LOCAL_PORT}}"
