#!/usr/bin/env bash
# cf0-setup-system.sh — One-time system tuning for LLM workloads
# Run as: sudo bash /opt/cf0-scripts/cf0-setup-system.sh
#
# Idempotent — safe to re-run.
set -euo pipefail

LOCAL_USER="${SUDO_USER:-r}"
LOCAL_HOME=$(eval echo "~$LOCAL_USER")

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── Kernel tuning ───────────────────────────────────────────────────
log "Kernel tuning..."
if ! grep -q 'vm.max_map_count=1048576' /etc/sysctl.d/99-llm.conf 2>/dev/null; then
    cat > /etc/sysctl.d/99-llm.conf << 'EOF'
vm.max_map_count=1048576
fs.file-max=1048576
vm.swappiness=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10
EOF
    sysctl -p /etc/sysctl.d/99-llm.conf
    log "  Applied"
else
    log "  Already applied"
fi

if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
    echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
fi

# ── User limits ─────────────────────────────────────────────────────
log "User limits..."
if ! grep -q "$LOCAL_USER.*nofile" /etc/security/limits.d/99-llm.conf 2>/dev/null; then
    cat > /etc/security/limits.d/99-llm.conf << EOF
$LOCAL_USER soft nofile 65536
$LOCAL_USER hard nofile 65536
$LOCAL_USER soft memlock unlimited
$LOCAL_USER hard memlock unlimited
EOF
    log "  Set"
else
    log "  Already set"
fi

# ── Firewall (LAN only) ────────────────────────────────────────────
log "Firewall..."
if command -v ufw &>/dev/null; then
    ufw --force enable
    for rule in \
        "22:SSH" \
        "11434:Ollama" \
        "8080:Open WebUI" \
        "8081:SearXNG" \
        "3000:OpenRAG" \
        "5601:OS Dashboards" \
        "47334:MindsDB HTTP" \
        "47335:MindsDB MySQL" \
        "42617:ZeroClaw" \
        "8000:Cognee" \
        "5540:RedisInsight" \
    ; do
        port="${rule%%:*}"
        desc="${rule#*:}"
        ufw allow from 192.168.0.0/24 to any port "$port" proto tcp comment "$desc" 2>/dev/null || true
    done
    ufw reload
    log "  UFW configured — LAN only"
else
    log "  UFW not installed, skipping"
fi

# ── Create data dirs ───────────────────────────────────────────────
log "Data directories..."
for d in /home/r/.ollama/models /home/r/searxng /home/r/mindsdb /home/r/.zeroclaw; do
    mkdir -p "$d"
    chown "$LOCAL_USER:$LOCAL_USER" "$d"
done

# ── MindsDB config ─────────────────────────────────────────────────
if [[ ! -f /home/r/mindsdb/mindsdb_config.json ]]; then
    cat > /home/r/mindsdb/mindsdb_config.json << 'EOF'
{
  "config_version": "1.4",
  "storage_dir": "/root/mindsdb_storage",
  "api": {
    "http": {"host": "0.0.0.0", "port": 47334},
    "mysql": {"host": "0.0.0.0", "port": 47335}
  }
}
EOF
    chown "$LOCAL_USER:$LOCAL_USER" /home/r/mindsdb/mindsdb_config.json
    log "  MindsDB config created"
fi

# ── Docker volume for Open WebUI ───────────────────────────────────
if ! docker volume inspect open-webui-data &>/dev/null; then
    docker volume create open-webui-data
    log "  open-webui-data volume created"
fi

# ── OpenRAG .env ───────────────────────────────────────────────────
COMPOSE_ENV="/opt/cf0-scripts/compose/.env"
if [[ ! -f "$COMPOSE_ENV" ]]; then
    OPENSEARCH_PW=$(openssl rand -base64 16 | tr -d '/+=' | head -c20)
    cp /opt/cf0-scripts/compose/.env.example "$COMPOSE_ENV"
    sed -i "s/changeme_generateA1!/${OPENSEARCH_PW}A1!/" "$COMPOSE_ENV"
    sed -i "s/^LANGFLOW_SUPERUSER_PASSWORD=.*/LANGFLOW_SUPERUSER_PASSWORD=${OPENSEARCH_PW}/" "$COMPOSE_ENV"
    chown "$LOCAL_USER:$LOCAL_USER" "$COMPOSE_ENV"
    log "  .env created with generated OpenSearch password"
else
    log "  .env already exists"
fi

# ── Shell aliases ──────────────────────────────────────────────────
log "Shell aliases..."
MARKER="# --- cf0 LLM stack aliases ---"
if ! grep -q "$MARKER" "$LOCAL_HOME/.bashrc" 2>/dev/null; then
    cat >> "$LOCAL_HOME/.bashrc" << 'ALIASES'

# --- cf0 LLM stack aliases ---
alias cf0='sudo /opt/cf0-scripts/cf0-stack.sh'
alias cf0-up='sudo /opt/cf0-scripts/cf0-stack.sh up'
alias cf0-down='sudo /opt/cf0-scripts/cf0-stack.sh down'
alias cf0-status='sudo /opt/cf0-scripts/cf0-stack.sh status'
alias cf0-health='sudo /opt/cf0-scripts/cf0-stack.sh health'
alias cf0-logs='sudo /opt/cf0-scripts/cf0-stack.sh logs'
alias llm-status='sudo /opt/cf0-scripts/cf0-stack.sh status'
alias llm-models='docker exec ollama ollama list'
alias llm-running='docker exec ollama ollama ps'
alias llm-chat='docker exec -it ollama ollama run qwen3.5:4b'
alias llm-think='docker exec -it ollama ollama run deepseek-r1:8b'
alias llm-big='docker exec -it ollama ollama run qwen3.5:72b'
alias llm-code='docker exec -it ollama ollama run codestral:22b'
# --- end cf0 aliases ---
ALIASES
    chown "$LOCAL_USER:$LOCAL_USER" "$LOCAL_HOME/.bashrc"
    log "  Added to .bashrc"
else
    log "  Already in .bashrc"
fi

log ""
log "System setup complete. Next: cf0-stack.sh up"
