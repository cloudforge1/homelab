#!/usr/bin/env bash
# cf0-stack.sh — Docker Compose management for cf0 LLM + AI Tools Stack
#
# Usage:
#   cf0-stack.sh up         — Start all services
#   cf0-stack.sh down       — Stop all services
#   cf0-stack.sh restart    — Restart all services
#   cf0-stack.sh status     — Show service status + health
#   cf0-stack.sh logs [svc] — Follow logs (all or specific service)
#   cf0-stack.sh pull       — Pull latest images
#   cf0-stack.sh health     — Run health checks
#   cf0-stack.sh models     — List Ollama models
#   cf0-stack.sh model-pull — Pull model tier sets
#   cf0-stack.sh model-sync — Pull env-enabled optional slow models
#
set -euo pipefail

COMPOSE_DIR="/opt/cf0-scripts/compose"
CORE="$COMPOSE_DIR/docker-compose.yml"
OPENRAG="$COMPOSE_DIR/docker-compose.openrag.yml"
EXPAND="$COMPOSE_DIR/docker-compose.expand.yml"
EXPAND_ENV="$COMPOSE_DIR/expand.env"
ENV_FILE="$COMPOSE_DIR/.env"
MODEL_ENV_FILE="$COMPOSE_DIR/ollama-models.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; }

# Compose command wrappers
dc_core()    { docker compose --env-file "$ENV_FILE" -f "$CORE" "$@"; }
dc_openrag() { docker compose --env-file "$ENV_FILE" -f "$OPENRAG" "$@"; }
dc_expand()  { docker compose --env-file "$EXPAND_ENV" -f "$EXPAND" "$@"; }

health_check() {
    local name="$1" port="$2" path="${3:-/}" max="${4:-10}"
    for _ in $(seq 1 "$max"); do
        if curl -sf -o /dev/null --max-time 2 "http://127.0.0.1:${port}${path}" 2>/dev/null; then
            ok "$name (port $port)"
            return 0
        fi
        sleep 1
    done
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        warn "$name port $port listening but HTTP check failed"
        return 0
    fi
    fail "$name NOT responding on port $port"
    return 1
}

cmd_up() {
    log "Starting core services..."
    dc_core up -d
    log "Starting OpenRAG stack..."
    dc_openrag up -d
    log "Starting Expand stack..."
    dc_expand up -d
    log "All services started. Run: cf0-stack.sh health"
}

cmd_down() {
    log "Stopping Expand stack..."
    dc_expand down 2>/dev/null || true
    log "Stopping OpenRAG stack..."
    dc_openrag down 2>/dev/null || true
    log "Stopping core services..."
    dc_core down
    log "All services stopped."
}

cmd_restart() {
    cmd_down
    sleep 2
    cmd_up
}

cmd_pull() {
    log "Pulling latest images (core)..."
    dc_core pull
    log "Pulling latest images (OpenRAG)..."
    dc_openrag pull
    log "Pulling latest images (Expand)..."
    dc_expand pull
    log "Done. Run: cf0-stack.sh restart  to apply new images."
}

cmd_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  cf0 Docker LLM + AI Tools Stack"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "── RESOURCES ─────────────────────────────────────────────────"
    FREE_MEM=$(free -g | awk '/Mem:/ {print $7}')
    TOTAL_MEM=$(free -g | awk '/Mem:/ {print $2}')
    echo "  RAM: ${FREE_MEM}GB free / ${TOTAL_MEM}GB total"
    echo "  CPU: $(nproc) threads, load:$(uptime | awk -F'load average:' '{print $2}')"
    if command -v nvidia-smi &>/dev/null; then
        echo "  GPU: $(nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader 2>/dev/null)"
    fi
    echo "  Disk: $(df -h /home | tail -1 | awk '{print $4 " free / " $2 " total"}')"
    echo ""
    echo "── CORE CONTAINERS ──────────────────────────────────────────"
    dc_core ps -a --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "── OPENRAG CONTAINERS ───────────────────────────────────────"
    dc_openrag ps -a --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
    echo ""
    echo "── EXPAND CONTAINERS ───────────────────────────────────"
    dc_expand ps -a --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
    echo ""
    echo "── LOADED MODELS ────────────────────────────────────────────"
    docker exec ollama ollama ps 2>/dev/null || echo "  (none running)"
    echo ""
    echo "── INSTALLED MODELS ─────────────────────────────────────────"
    docker exec ollama ollama list 2>/dev/null | head -20 || echo "  (none)"
    echo ""
    echo "── ENDPOINTS ────────────────────────────────────────────────"
    IP=$(hostname -I | awk '{print $1}')
    echo "  Ollama API:      http://${IP}:11434"
    echo "  Open WebUI:      http://${IP}:8080"
    echo "  SearXNG:         http://${IP}:8081"
    echo "  OpenRAG:         http://${IP}:3000"
    echo "  OS Dashboards:   http://${IP}:5601"
    echo "  MindsDB HTTP:    http://${IP}:47334"
    echo "  MindsDB MySQL:   ${IP}:47335"
    echo "  Cognee:          http://${IP}:8000"
    echo "  ZeroClaw:        http://${IP}:42617"
    echo "  RedisInsight:    http://${IP}:5540"
    echo "  n8n:            http://${IP}:5679"
    echo "  Nuclio:          http://${IP}:8070"
    echo "  Qdrant:          http://${IP}:6333"
    echo "  mCaptcha:        http://${IP}:7000"
    echo "  TensorLake:      http://${IP}:8900"
    echo "  mem0:            http://${IP}:8010"
    echo "  Nautilus:        http://${IP}:8889"
    echo "  OpenBB:          http://${IP}:6900"
    echo "  PG (tools):      ${IP}:4433"
    echo ""
}

cmd_health() {
    log "Running health checks..."
    FAIL=0
    health_check "ollama"       11434 "/api/tags"   10 || ((FAIL++))
    health_check "open-webui"   8080  "/"           10 || ((FAIL++))
    health_check "searxng"      8081  "/"           10 || ((FAIL++))
    health_check "mindsdb"      47334 "/api/status" 10 || ((FAIL++))
    health_check "zeroclaw"     42617 "/"           10 || ((FAIL++))
    health_check "cognee"       8000  "/"           10 || ((FAIL++))
    health_check "redisinsight" 5540  "/"           10 || ((FAIL++))
    health_check "openrag"      3000  "/"           10 || ((FAIL++))
    health_check "osdashboards" 5601  "/"           10 || ((FAIL++))
    health_check "n8n"          5679 "/"           10 || ((FAIL++))
    health_check "nuclio"       8070 "/"           10 || ((FAIL++))
    health_check "qdrant"       6333 "/readyz"     10 || ((FAIL++))
    health_check "mcaptcha"     7000 "/"           10 || ((FAIL++))
    health_check "tensorlake"   8900 "/"           10 || ((FAIL++))
    health_check "mem0"         8010 "/"           10 || ((FAIL++))
    health_check "nautilus"     8889 "/"           10 || ((FAIL++))
    health_check "openbb"       6900 "/"           10 || ((FAIL++))
    health_check "pg-tools"     4433 "/"            5 || ((FAIL++))
    echo ""
    if [[ $FAIL -gt 0 ]]; then
        warn "${FAIL} service(s) unhealthy"
        return 1
    else
        ok "All services healthy"
    fi
}

cmd_logs() {
    local svc="${1:-}"
    if [[ -n "$svc" ]]; then
        dc_core logs -f "$svc" 2>/dev/null || dc_openrag logs -f "$svc" 2>/dev/null || dc_expand logs -f "$svc" 2>/dev/null || {
            fail "Service '$svc' not found in any compose file"
            exit 1
        }
    else
        dc_core logs -f &
        dc_openrag logs -f &
        dc_expand logs -f &
        wait
    fi
}

cmd_models() {
    docker exec ollama ollama list 2>/dev/null || fail "Ollama not running"
}

cmd_model_pull() {
    log "Pulling model tiers..."
    echo ""
    echo "── TIER 1: GPU essentials (<6GB VRAM) ──"
    docker exec ollama ollama pull qwen3.5:4b
    docker exec ollama ollama pull nomic-embed-text
    docker exec ollama ollama pull deepseek-r1:8b

    echo ""
    echo "── TIER 2: Medium (CPU/GPU split) ──"
    docker exec ollama ollama pull qwen3.5:27b
    docker exec ollama ollama pull deepseek-r1:32b
    docker exec ollama ollama pull codestral:22b

    echo ""
    echo "── TIER 3: Big CPU ──"
    docker exec ollama ollama pull qwen3.5:35b
    docker exec ollama ollama pull deepseek-r1:70b
    docker exec ollama ollama pull llama3.1:70b

    echo ""
    log "Model pulls complete."
    docker exec ollama ollama list
}

cmd_model_sync() {
    if [[ ! -f "$MODEL_ENV_FILE" ]]; then
        fail "Missing model flag file: $MODEL_ENV_FILE"
        exit 1
    fi
    log "Ensuring Ollama is running..."
    dc_core up -d ollama >/dev/null
    log "Syncing env-enabled optional slow models from $MODEL_ENV_FILE ..."
    dc_core run --rm ollama-model-sync
}

# ── Main ─────────────────────────────────────────────────────────────
case "${1:-help}" in
    up)         cmd_up ;;
    down)       cmd_down ;;
    restart)    cmd_restart ;;
    pull)       cmd_pull ;;
    status|st)  cmd_status ;;
    health|hc)  cmd_health ;;
    logs)       shift; cmd_logs "$@" ;;
    models)     cmd_models ;;
    model-pull) cmd_model_pull ;;
    model-sync) cmd_model_sync ;;
    *)
        echo "cf0-stack.sh — Docker Compose management for cf0"
        echo ""
        echo "Usage: cf0-stack.sh <command>"
        echo ""
        echo "Commands:"
        echo "  up          Start all services"
        echo "  down        Stop all services"
        echo "  restart     Restart all services"
        echo "  pull        Pull latest images"
        echo "  status      Show dashboard (alias: st)"
        echo "  health      Run health checks (alias: hc)"
        echo "  logs [svc]  Follow logs (all or specific service)"
        echo "  models      List installed Ollama models"
        echo "  model-pull  Pull all model tiers"
        echo "  model-sync  Pull env-enabled optional slow models"
        ;;
esac
