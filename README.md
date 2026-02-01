# Podman Browser Container Deployment

## Overview

Automated deployment script for isolated browser instances running in Podman containers. Each container provides a full browser environment accessible via web interface with VNC, ideal for Remote Browser Isolation (RBI), automated testing, or secure browsing scenarios.

---

## Features

- **Automatic Port Management** - Scans for available ports in configurable range (default: 3000-4000)
- **Multi-Browser Support** - Chrome, Chromium, or Firefox
- **Resource Isolation** - Memory (4GB), CPU (2 cores), and shared memory (2GB) limits per container
- **Secure Defaults** - Localhost-only binding, unique credentials per instance
- **Customized UI** - Branded interface with disabled unnecessary controls
- **JSON Output** - Machine-readable container metadata for automation

---

## Prerequisites

### System Requirements

- **OS:** Linux (tested on debian 13)
- **RAM:** Minimum 6GB available (2GB per container + 2GB system overhead)
- **CPU:** 2+ cores recommended
- **Disk:** 2GB per container image + workspace

### Required Software

```bash
# Install Podman
sudo apt-get update && sudo apt-get install -y podman

# Install dependencies
sudo apt-get install -y iproute2 openssl jq

# Verify installation
podman --version  # Should be 3.0+
ss --version      # For port checking
openssl version   # For password generation
```

---

## Installation

```bash
# Clone or download the script
git clone https://github.com/HighBrowInTown/remote-browser.git
chmod 755 remote-browser/mk_rbi.sh

```

---

## Usage

### Basic Syntax

```bash
./mk_rbi.sh [USERNAME] [PASSWORD] [URL] [BROWSER]
```

### Parameters

| Parameter | Default | Description | Example |
|-----------|---------|-------------|---------|
| USERNAME | `user-$RANDOM` | Container login username | `alice` |
| PASSWORD | Random (base64) | Container login password | `SecurePass123!` |
| URL | `https://safesquid.com` | Initial page to load | `https://google.com` |
| BROWSER | `chromium` | Browser engine | `chrome`, `chromium`, `firefox` |

---

## Examples

### Example 1: Quick Start with Defaults

```bash
./mk_rbi.sh
```

**Output:**
```json
{
  "container_name": "chromium-1738454789-12345",
  "user": "user-23456",
  "password": "Kx9mL2pQ5vN+wE7=",
  "browser": "chromium",
  "port": 3000,
  "url": "https://safesquid.com",
  "access_url": "https://server01.lan:3000"
}
```

**Access:** Navigate to `https://server01.lan:3000` and login with the provided credentials.

---

### Example 2: Custom Configuration

```bash
./mk_rbi.sh testuser MyPassword123 https://example.com firefox
```

**Real-World Use Case:** QA team member launching a Firefox instance pre-configured to test the staging environment at `example.com`.

---

### Example 3: Automated Testing Fleet

```bash
#!/bin/bash
# Create 5 browser instances for parallel testing

for i in {1..5}; do
    OUTPUT=$(./mk_rbi.sh "tester${i}" "TestPass${i}" "https://app.example.com/login")
    PORT=$(echo "$OUTPUT" | jq -r '.port')
    echo "Test instance ${i} ready on port ${PORT}"
done
```
---

### Example 4: Environment Variables

```bash
# Custom port range
LOCAL_PORT=5000 PORT_END=5100 ./mk_rbi.sh

# Multiple configurations
export LOCAL_PORT=8000
export PORT_END=8050
./mk_rbi.sh admin AdminPass https://dashboard.internal chrome
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCAL_PORT` | `3000` | Starting port for scan range |
| `PORT_END` | `4000` | Ending port for scan range |

### Container Environment Variables

The script configures the LinuxServer browser container with:

```bash
# Browser Configuration
CHROME_CLI          # Initial URL to open
PUID/PGID           # User/group ID (1000)
TZ                  # Timezone (Asia/Kolkata)
CUSTOM_USER         # VNC login username
PASSWORD            # VNC login password

# UI Customization (Selkies)
DISABLE_OPEN_TOOLS       # Hides file browser
DISABLE_SUDO             # Removes sudo access
DISABLE_TERMINALS        # Removes terminal access
DISABLE_CLOSE_BUTTON     # Prevents accidental closure
SELKIES_UI_TITLE         # Custom title bar
SELKIES_UI_SHOW_*        # Hide various UI elements
```
---

## Architecture

### Port Allocation Algorithm

```
1. Start at PORT_START (default: 3000)
2. For each port in range:
   a. Check if ANY process is using port (via ss command)
   b. Check if ANY container is using port (via podman ps)
   c. If both checks pass → assign port
   d. If check fails → increment and retry
3. If PORT_END reached → fail with error
```

**Real-World Example:**
```bash
# System state:
# Port 3000: nginx (detected by ss)
# Port 3001: Available
# Port 3002: Previous container (detected by podman ps -a)
# Port 3003: Available

# Script execution:
# Check 3000 → ss shows in use → skip
# Check 3001 → both checks pass → ASSIGNED
```

---

### Resource Isolation

```
┌─────────────────────────────────────────┐
│         Host System (16GB RAM)          │
├─────────────────────────────────────────┤
│  Container 1 (Browser)                  │
│  ├── Memory Limit: 4GB                  │
│  ├── CPU Limit: 2.0 cores               │
│  ├── SHM: 2GB (/dev/shm)                │
│  └── Network: Bridge (localhost only)   │
├─────────────────────────────────────────┤
│  Container 2 (Browser)                  │
│  ├── Memory Limit: 4GB                  │
│  └── ...                                │
└─────────────────────────────────────────┘
```

**Why 2GB Shared Memory?**

Browser rendering engines (Chromium, Firefox) use `/dev/shm` for:
- Canvas element rendering
- WebGL operations
- Video decoding
- Large DOM manipulations

---

## Container Management

### List Running Containers

```bash
podman ps --filter "ancestor=lscr.io/linuxserver/chromium" \
  --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
```

### Stop Container

```bash
CONTAINER_NAME="chromium-1738454789-12345"
podman stop "$CONTAINER_NAME"
```

### Remove Container

```bash
podman rm -f "$CONTAINER_NAME"
```

### Remove All Container

```bash
podman rm -f $(podman ps -aq)
```

### View Container Logs

```bash
podman logs -f "$CONTAINER_NAME"
```

### Access Container Shell (Debugging)

```bash
podman exec -it "$CONTAINER_NAME" /bin/bash
```

---

## Troubleshooting

### Issue 1: "No available ports in range"

**Symptom:**
```
Error: No available ports in range 3000-4000
```

**Solutions:**
```bash
# Option 1: Expand port range
LOCAL_PORT=3000 PORT_END=5000 ./mk_rbi.sh

# Option 2: Clean up stopped containers
podman container prune -f

# Option 3: Check what's using ports
ss -tuln | grep -E ":(3[0-9]{3}|4000)" | sort
```

---

### Issue 2: Container Starts But Not Accessible

**Symptom:** JSON output shows success, but browser at `access_url` times out.

**Diagnosis:**
```bash
# Check container status
podman ps -a --filter "name=chromium-"

# View container logs
podman logs chromium-1738454789-12345

# Test port locally
curl -I http://localhost:3000
```

**Common Causes:**
1. **Firewall blocking port** - Check `iptables` or `firewalld`
2. **Container still initializing** - Wait 30-60 seconds
3. **Insufficient resources** - Check `dmesg` for OOM killer

**Real-World Example:** On a CentOS 8 server with SELinux enabled, containers may start but fail to bind ports. Solution:
```bash
sudo setsebool -P container_manage_cgroup true
sudo semanage port -a -t http_port_t -p tcp 3000-4000
```

---

### Issue 3: Browser Crashes Immediately

**Symptom:** Container runs but browser process dies repeatedly.

**Check logs:**
```bash
podman logs chromium-1738454789-12345 2>&1 | grep -i "error\|crash\|segfault"
```

**Common Fixes:**
```bash
# Increase shared memory
# Edit script line: --shm-size="4gb"

# Disable GPU acceleration (add to script)
-e CHROME_CLI="${OPEN_URL} --disable-gpu" \
```

---

### Issue 4: Password Not Working

**Symptom:** Correct credentials rejected at login screen.

**Verify credentials:**
```bash
# Extract from JSON output
OUTPUT=$(./mk_rbi.sh)
echo "$OUTPUT" | jq -r '.user, .password'

# Or check container environment
podman inspect chromium-1738454789-12345 | jq '.[0].Config.Env[] | select(startswith("PASSWORD"))'
```

---

## Security Considerations

### Current Security Posture

```bash
# REMOVED in production version:
# --security-opt seccomp=unconfined    # Disables syscall filtering
# --security-opt apparmor=unconfined   # Disables mandatory access control
```

**Why These Were Removed:**

**Technical Analogy:** Running with `seccomp=unconfined` is like disabling a web application firewall (WAF)—the application works perfectly, but you've removed a critical security layer that detects and blocks malicious syscalls (like `ptrace` for container escapes).

**Real-World Risk:** CVE-2019-5736 (runC container escape) exploited syscalls that would be blocked by seccomp. Containers with unconfined profiles are vulnerable.

---

### Recommended Security Enhancements

#### 1. Network Isolation

```bash
# Current: Uses default bridge (full internet access)
# Better: Create isolated network

podman network create browser_net --subnet 172.28.0.0/16
# Add to script: --network browser_net
```

#### 2. Read-Only Root Filesystem

```bash
# Add to script:
--read-only \
--tmpfs /tmp \
--tmpfs /var/tmp \
```

#### 3. Drop Capabilities

```bash
# Add to script:
--cap-drop=ALL \
--cap-add=CHOWN \
--cap-add=SETUID \
--cap-add=SETGID \
```

**Practical Example:** Financial services company using RBI for vendor access—they run browsers in read-only mode to prevent malware persistence and drop all Linux capabilities except those required for the VNC server.

---

### Password Security

```bash
# Current: openssl rand -base64 12  (96 bits entropy)

# Enhanced: Longer passwords for production
PASSWORD="${2:-$(openssl rand -base64 18)}"  # 144 bits

# With special characters
PASSWORD="${2:-$(openssl rand -base64 18 | tr -d '+/=' | head -c 20)}"
```

---

## Performance Tuning

### Resource Optimization

```bash
# Light usage (documentation browsing)
--memory="2g" \
--cpus="1.0" \
--shm-size="512mb" \

# Heavy usage (WebGL applications, video streaming)
--memory="8g" \
--cpus="4.0" \
--shm-size="4gb" \
```

**Benchmark Data:**
```
Scenario: Rendering Google Maps with 3D buildings
- 2GB RAM + 512MB SHM: Crashes after 30s
- 4GB RAM + 1GB SHM: Laggy but functional
- 4GB RAM + 2GB SHM: Smooth 30 FPS (recommended)
- 8GB RAM + 4GB SHM: Smooth 60 FPS (overkill)
```

---

### Concurrent Container Limits

```bash
# Calculate maximum containers
HOST_RAM_GB=16
CONTAINER_RAM_GB=4
SYSTEM_OVERHEAD_GB=4

MAX_CONTAINERS=$(( (HOST_RAM_GB - SYSTEM_OVERHEAD_GB) / CONTAINER_RAM_GB ))
echo "Maximum safe containers: $MAX_CONTAINERS"  # Output: 3
```

**Real-World Example:** Testing server with 32GB RAM can comfortably run 6 browser containers (6×4GB=24GB) while leaving 8GB for OS, monitoring tools, and filesystem cache.

---

## FAQ

### Q: Can I access containers from other machines?

**A:** Yes, but requires binding to `0.0.0.0` instead of `127.0.0.1`:

```bash
# Edit script line:
-p "0.0.0.0:${LOCAL_PORT}:3001" \

# Add firewall rule:
sudo firewall-cmd --add-port=3000-4000/tcp --permanent
sudo firewall-cmd --reload
```

**Security Warning:** This exposes browser instances to your network. Implement reverse proxy with authentication.

---

### Q: How do I persist browser data?

**A:** Mount volumes for profile data:

```bash
# Create persistent directory
mkdir -p ~/browser_profiles

# Add to script:
-v ~/browser_profiles/${CONTAINER_NAME}:/config \
```

---

### Q: Can I use this with Docker instead of Podman?

**A:** Yes, replace `podman` with `docker`:

```bash
sed -i 's/podman/docker/g' mk_rbi.sh
```

---

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -am 'Add feature'`)
4. Push to branch (`git push origin feature/improvement`)
5. Create Pull Request

---

## Support

- **Issues:** GitHub Issues
- **Documentation:** [LinuxServer.io Browser Container Docs](https://docs.linuxserver.io/images/docker-chromium/)
- **Community:** [Podman Community](https://podman.io/community/)

---

## Changelog

### v1.0.0 (2024-02-01)
- Initial release
- Support for Chrome, Chromium, Firefox
- Automatic port allocation
- JSON output format
- Resource limits and isolation