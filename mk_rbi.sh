#!/bin/bash

USER_NAME=${1:-"user-${RANDOM}"}
PASSWORD=${2:-"$(openssl rand -base64 12)"}
OPEN_URL=${3:-"https://safesquid.com"}
BROWSER=${4:-"chromium"}

# Get all ports already used by podman containers
PORT_START="${LOCAL_PORT:-3000}"
PORT_END="${PORT_END:-4000}"  # Search range
USED_PORTS=$(podman ps -a --format "{{.Ports}}" | awk -F'[:>-]' '{ print $2 }' | sort -n | uniq)

# Validate browser choice
VALID_BROWSERS=("chrome" "chromium" "firefox")
[[ ! " ${VALID_BROWSERS[@]} " =~ " ${BROWSER} " ]] && echo "Error: Invalid browser '${BROWSER}'. Choose from: ${VALID_BROWSERS[*]}" && exit 1

# Function to check if port is available
CHK_PORT_AVL () 
{
    local port=$1
    
    # Check if port is in use by any process (not just podman)
    if ss -tuln | grep -q ":${port} "; then
        return 1  # Port in use
    fi
    
    # Check if podman container is using this port
    if podman ps -a --format "{{.Ports}}" | grep -qE "\b${port}\b"; then
        return 1  # Port in use by container
    fi
    
    return 0  # Port available
}

# Find next available port
GET_PORT () 
{
    local start_port=$1
    local end_port=$2
    
    for ((port=start_port; port<=end_port; port++)); do
        if CHK_PORT_AVL "$port"; then
            echo "$port"
            return 0
        fi
    done
    
    echo "Error: No available ports in range ${start_port}-${end_port}" >&2
    return 1
}

# Get available port
if ! LOCAL_PORT=$(GET_PORT "$PORT_START" "$PORT_END"); then
    exit 1
fi

# Generate unique container name
CONTAINER_NAME="${BROWSER}-$(date +%s)-${RANDOM}"

# Create a podman container
podman run -d \
  --name="${CONTAINER_NAME}" \
  -e CHROME_CLI="${OPEN_URL}" \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Kolkata \
  -e CUSTOM_USER="${USER_NAME}" \
  -e PASSWORD="${PASSWORD}" \
  -p "${LOCAL_PORT}":3001 \
  -e DISABLE_OPEN_TOOLS="True" \
  -e DISABLE_SUDO="True" \
  -e DISABLE_TERMINALS="True" \
  -e DISABLE_CLOSE_BUTTON="True" \
  -e SELKIES_UI_TITLE="SafeSquid RBI" \
  -e SELKIES_UI_SHOW_LOGO="False" \
  -e SELKIES_UI_SHOW_CORE_BUTTONS="False" \
  -e SELKIES_UI_SIDEBAR_SHOW_VIDEO_SETTINGS="False" \
  -e SELKIES_UI_SIDEBAR_SHOW_SCREEN_SETTINGS="False" \
  -e SELKIES_UI_SIDEBAR_SHOW_STATS="False" \
  -e SELKIES_UI_SIDEBAR_SHOW_APPS="False" \
  -e SELKIES_UI_SIDEBAR_SHOW_SHARING="False" \
  --shm-size="2gb" \
  --memory="4g" \
  --cpus="2.0" \
  --restart unless-stopped \
  lscr.io/linuxserver/"${BROWSER}":latest

# Output results in JSON format for easy parsing
cat <<EOF
{
  "container_name": "${CONTAINER_NAME}",
  "user": "${USER_NAME}",
  "password": "${PASSWORD}",
  "browser": "${BROWSER}",
  "port": ${LOCAL_PORT},
  "url": "${OPEN_URL}",
  "access_url": "https://$(hostname).$(hostname -d):${LOCAL_PORT}"
}
EOF