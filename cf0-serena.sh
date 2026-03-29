#!/usr/bin/env bash
# cf0-serena.sh — Docker Compose management for Serena MCP server
#
# Remote usage model:
# - Serena runs on cf0 and can only access repos visible on cf0.
# - Mounted host root defaults to /home/r and appears in the container as /workspaces/home-r.
# - The MCP endpoint is private on 127.0.0.1 and intended for SSH tunneling from your workstation.
# - Serena is stateful: one active project per server instance.
#
set -euo pipefail

COMPOSE_DIR="/opt/cf0-scripts/compose"
SERENA_COMPOSE="$COMPOSE_DIR/docker-compose.serena.yml"
ENV_FILE="$COMPOSE_DIR/.env"
SERENA_ROOT="/opt/cf0-scripts/vendor/serena"
SERENA_CONFIG_DIR="/home/r/serena-config"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; }

dc() { docker compose --env-file "$ENV_FILE" -f "$SERENA_COMPOSE" "$@"; }

container_health() {
  docker inspect cf0-serena --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}" 2>/dev/null || echo missing
}

cmd_build() {
  log "Building Serena image..."
  dc build serena
  ok "Image built"
}

cmd_up() {
  mkdir -p "$SERENA_CONFIG_DIR"
  log "Starting Serena MCP container..."
  dc up -d --build serena
  cmd_status
}

cmd_down() {
  log "Stopping Serena MCP container..."
  dc down
  ok "Serena stopped"
}

cmd_restart() {
  log "Restarting Serena MCP container..."
  dc up -d --build --force-recreate serena
  cmd_status
}

cmd_status() {
  local health
  health="$(container_health)"
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  cf0 Serena MCP"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  dc ps
  echo ""
  echo "── STATUS ───────────────────────────────────────────────────"
  echo "  Health: ${health}"
  echo "  Endpoint: http://127.0.0.1:${SERENA_PORT:-9121}/mcp"
  echo "  Context: ${SERENA_CONTEXT:-ide}"
  echo "  Serena source ref: ${SERENA_VERSION:-main}"
  echo "  Host repo root: ${SERENA_PROJECTS_HOST_ROOT:-/home/r}"
  echo "  Container repo root: ${SERENA_PROJECTS_CONTAINER_ROOT:-/workspaces/home-r}"
  echo ""
  echo "── HOW TO USE FROM YOUR MACHINE ─────────────────────────────"
  echo "  1. Create a tunnel: ssh -N -L ${SERENA_PORT:-9121}:127.0.0.1:${SERENA_PORT:-9121} r@cf0"
  echo "  2. Point your MCP client at: http://127.0.0.1:${SERENA_PORT:-9121}/mcp"
  echo "  3. Activate a remote repo path under ${SERENA_PROJECTS_CONTAINER_ROOT:-/workspaces/home-r}"
  echo ""
  echo "  Constraint: repos that exist only on your workstation are not accessible here."
}

cmd_logs() {
  dc logs -f serena
}

cmd_health() {
  log "Checking Serena TCP endpoint..."
  if python3 - <<PY
import socket
s = socket.create_connection(("127.0.0.1", ${SERENA_PORT:-9121}), 2)
s.close()
PY
  then
    ok "Port ${SERENA_PORT:-9121} is accepting connections"
  else
    fail "Port ${SERENA_PORT:-9121} is not accepting connections"
    exit 1
  fi

  local health
  health="$(container_health)"
  if [[ "$health" == "healthy" ]]; then
    ok "Container healthcheck is healthy"
  else
    warn "Container healthcheck reports: $health"
  fi
}

cmd_update() {
  local target="${SERENA_VERSION:-main}"
  log "Updating Serena source checkout to ${target}..."
  git -C "$SERENA_ROOT" fetch --tags --prune origin main
  if [[ "$target" == "main" ]]; then
    git -C "$SERENA_ROOT" checkout -B main origin/main
  else
    git -C "$SERENA_ROOT" checkout "$target"
  fi
  cmd_restart
}

case "${1:-help}" in
  build)   cmd_build ;;
  up)      cmd_up ;;
  down)    cmd_down ;;
  restart) cmd_restart ;;
  status|st) cmd_status ;;
  logs)    cmd_logs ;;
  update)  cmd_update ;;
  health|hc) cmd_health ;;
  *)
    echo "cf0-serena.sh — Docker Compose management for Serena MCP"
    echo ""
    echo "Usage: cf0-serena.sh <command>"
    echo ""
    echo "Commands:"
    echo "  build      Build the Serena image"
    echo "  up         Start or recreate the container"
    echo "  down       Stop the container"
    echo "  restart    Recreate the container"
    echo "  status     Show status and connection info"
    echo "  logs       Follow container logs"
    echo "  update     Update Serena source, rebuild, restart"
    echo "  health     Run host-side health checks"
    exit 1
    ;;
 esac
