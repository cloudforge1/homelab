#!/usr/bin/env bash
# cf0-ddns.sh — No-IP DDNS via Docker (idempotent)
# Run as: bash /opt/cf0-scripts/cf0-ddns.sh [--info]
#
# Sets up the No-IP Dynamic Update Client in Docker so that
# cfz.myvnc.com always resolves to this network's public IP.
# The router (TP-Link WR841N) port-forwards SSH to this host.
#
# Idempotent — safe to re-run. Will recreate container only if
# config changes (image, hostname, credentials).
set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────
CONTAINER_NAME="noip-duc"
IMAGE="ghcr.io/noipcom/noip-duc:latest"
DDNS_HOSTNAME="cfz.myvnc.com"
DDNS_USERNAME="6vxggq6"
DDNS_PASSWORD="XgoDnXSh8Rva"

# Router DDNS also configured (belt & suspenders):
#   all.ddnskey.com — updated by TP-Link WR841N built-in No-IP client
# ────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%H:%M:%S')] $*"; }

print_manual() {
    cat << 'MANUAL'
╔═══════════════════════════════════════════════════════════════════════╗
║              MANUAL SETUP — ROUTER & NO-IP ACCOUNT                  ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                     ║
║  1. ROUTER: TP-Link WR841N  (http://192.168.0.1  admin / admin)     ║
║  ─────────────────────────────────────────────────────────────────   ║
║                                                                     ║
║  a) DDNS (Dynamiczny DNS):                                          ║
║     • Provider: No-IP (www.noip.com)                                ║
║     • Domain:   all.ddnskey.com                                     ║
║     • Username: 6vxggq6                                             ║
║     • Password: XgoDnXSh8Rva                                       ║
║     • Enable:   ✓                                                   ║
║     • Status should show: "Powodzenie" (Success)                    ║
║                                                                     ║
║  b) Port Forwarding (Przekierowania → Serwery wirtualne):           ║
║     ┌──────────────┬───────────────┬───────────────┬───────┐        ║
║     │ Port usługi  │ Adres IP      │ Port wewnętrz.│ Proto │        ║
║     ├──────────────┼───────────────┼───────────────┼───────┤        ║
║     │ 22           │ 192.168.0.104 │ 22            │ TCP   │        ║
║     └──────────────┴───────────────┴───────────────┴───────┘        ║
║                                                                     ║
║     ⚠  CURRENT RULE forwards ports 2-65534 (ALL).                   ║
║        Recommended: delete it, add only port 22 (SSH).              ║
║        Add more rules as needed (80/443 for HTTP/HTTPS, etc.)       ║
║                                                                     ║
║  c) DHCP Reservation (Wiązanie IP i MAC):                           ║
║     Bind 192.168.0.104 to cf0's MAC so the IP never changes.       ║
║     Find MAC: ip link show | grep ether                              ║
║                                                                     ║
║  2. NO-IP ACCOUNT  (https://my.noip.com — robgrzelka@gmail.com)     ║
║  ─────────────────────────────────────────────────────────────────   ║
║                                                                     ║
║  • DDNS Keys → Group "CFX"                                          ║
║    - Username: 6vxggq6                                              ║
║    - Password: (set at creation, regenerate via dashboard)           ║
║    - Hostname: all.ddnskey.com                                      ║
║    - Grouped:  cfz.myvnc.com                                        ║
║                                                                     ║
║  • DNS Records:                                                     ║
║    - cfz.myvnc.com → A record, updated by Docker DUC               ║
║    - all.ddnskey.com → updated by both router + DUC                 ║
║                                                                     ║
║  3. TESTING                                                         ║
║  ─────────────────────────────────────────────────────────────────   ║
║                                                                     ║
║  From OUTSIDE the LAN (phone hotspot, VPS, etc.):                   ║
║    ssh r@cfz.myvnc.com                                              ║
║                                                                     ║
║  From INSIDE the LAN (NAT hairpin not supported):                   ║
║    ssh r@ubu1          # or ssh r@192.168.0.104                     ║
║                                                                     ║
║  Verify DNS:                                                        ║
║    dig +short cfz.myvnc.com    # should match: curl -s ifconfig.me  ║
║                                                                     ║
║  4. TROUBLESHOOTING                                                 ║
║  ─────────────────────────────────────────────────────────────────   ║
║                                                                     ║
║  • DUC logs:    docker logs noip-duc                                 ║
║  • DUC status:  docker ps -f name=noip-duc                           ║
║  • Recreate:    bash /opt/cf0-scripts/cf0-ddns.sh                    ║
║  • Public IP:   curl -s ifconfig.me                                  ║
║  • SSH refused from LAN via DDNS? → Normal. Use LAN IP instead.     ║
║  • SSH refused from outside? → Check router port forwarding +        ║
║    ISP might block port 22 (try port 2222 or use --port flag).      ║
║                                                                     ║
╚═══════════════════════════════════════════════════════════════════════╝
MANUAL
}

# ── --info flag: print manual and exit ──────────────────────────────
if [[ "${1:-}" == "--info" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    print_manual
    exit 0
fi

# ── Preflight ───────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    log "ERROR: docker not found. Install Docker first."
    exit 1
fi

# ── Desired container args ──────────────────────────────────────────
DESIRED_CMD='["-g","'"$DDNS_HOSTNAME"'","--username","'"$DDNS_USERNAME"'","--password","'"$DDNS_PASSWORD"'"]'

need_recreate=false

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    # Container exists — check if config matches
    CURRENT_IMAGE=$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Image}}' 2>/dev/null)
    CURRENT_CMD=$(docker inspect "$CONTAINER_NAME" --format '{{json .Config.Cmd}}' 2>/dev/null)
    CURRENT_RESTART=$(docker inspect "$CONTAINER_NAME" --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)

    if [[ "$CURRENT_IMAGE" != "$IMAGE" ]]; then
        log "Image changed: $CURRENT_IMAGE → $IMAGE"
        need_recreate=true
    elif [[ "$CURRENT_CMD" != "$DESIRED_CMD" ]]; then
        log "Config changed: args differ"
        need_recreate=true
    elif [[ "$CURRENT_RESTART" != "unless-stopped" ]]; then
        log "Restart policy changed: $CURRENT_RESTART → unless-stopped"
        need_recreate=true
    fi

    if [[ "$need_recreate" == "false" ]]; then
        # Config matches — just ensure it's running
        STATE=$(docker inspect "$CONTAINER_NAME" --format '{{.State.Status}}' 2>/dev/null)
        if [[ "$STATE" == "running" ]]; then
            log "Container '$CONTAINER_NAME' already running with correct config. Nothing to do."
        else
            log "Container '$CONTAINER_NAME' exists but state=$STATE. Starting..."
            docker start "$CONTAINER_NAME"
            log "Started."
        fi
        exit 0
    fi

    # Need to recreate
    log "Removing old container..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
else
    log "No existing container '$CONTAINER_NAME'. Creating..."
fi

# ── Pull latest image ──────────────────────────────────────────────
log "Pulling $IMAGE..."
docker pull "$IMAGE" --quiet

# ── Create and start ───────────────────────────────────────────────
log "Starting container '$CONTAINER_NAME'..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart=unless-stopped \
    "$IMAGE" \
    -g "$DDNS_HOSTNAME" \
    --username "$DDNS_USERNAME" \
    --password "$DDNS_PASSWORD" \
    >/dev/null

# ── Verify ─────────────────────────────────────────────────────────
sleep 3
STATE=$(docker inspect "$CONTAINER_NAME" --format '{{.State.Status}}' 2>/dev/null)
if [[ "$STATE" == "running" ]]; then
    log "✓ Container running. Checking DUC status..."
    docker logs "$CONTAINER_NAME" 2>&1 | tail -5
    log ""
    log "DDNS hostname: $DDNS_HOSTNAME"
    log "Public IP:     $(curl -s --connect-timeout 5 ifconfig.me || echo 'unknown')"
    log "DNS resolves:  $(dig +short "$DDNS_HOSTNAME" 2>/dev/null || echo 'dig not available')"
    log ""
    log "✓ Done. From outside: ssh r@$DDNS_HOSTNAME"
else
    log "✗ Container state: $STATE — check: docker logs $CONTAINER_NAME"
    exit 1
fi
