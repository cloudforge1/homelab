#!/usr/bin/env bash
# cf0-llm-tools.sh — Additional AI tools for cf0 server
# Run AFTER cf0-llm-stack.sh completes (Ollama, Open WebUI, SearXNG already up)
#
# Installs (toggle each with ENABLE_* booleans below):
#   1. Node.js 22 LTS     — CRITICAL dependency (always installed)
#   2. Rust toolchain      — dependency for ZeroClaw (auto-enabled if ZEROCLAW=true)
#   3. ZeroClaw            — personal AI assistant gateway (<5MB RAM, Rust)
#   4. MindsDB             — AI analytics query engine (Docker)
#   5. Cognee + Neo4j      — knowledge graph AI memory (Docker)
#   6. Flowise             — visual AI agent builder (Docker)
#   7. Unsloth Studio      — LLM inference/training UI (Docker)
#   8. Claude Code         — Anthropic CLI coding agent (npm)
#   9. MetaClaw            — meta-learning LLM proxy (pip)
#  10. uv                  — fast Python package manager
#  11. Gstack              — opinionated Claude Code wrapper (15 tools)
#  12. Onyx                — open source AI chat platform
#
# API-only (configured, not installed locally):
#   - MiniMax M2.5, Kimi K2.5 — too large for local, needs API keys
#
# Skipped:
#   - AutoResearch (Karpathy) — requires H100-class GPU, GTX 1060 insufficient
#   - Qwen 3.5 — already pulled via Ollama in cf0-llm-stack.sh
#
# Hardware: i9-9900K, 107GB RAM, GTX 1060 6GB (SM 6.1), 452GB free on /home
# Network: 100 Mbps, port 80 BLOCKED (HTTPS only)

set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOG="${CF0_LLM_TOOLS_LOG:-$HOME/.local/state/cf0-llm-tools.log}"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "===== cf0-llm-tools.sh started at $TIMESTAMP ====="

# ─────────────────── Feature Toggles ───────────────────
# Set to "true" to install, anything else to skip.
# Override from env: ENABLE_MINDSDB=true ./cf0-llm-tools.sh

ENABLE_ZEROCLAW="${ENABLE_ZEROCLAW:-true}"
ENABLE_MINDSDB="${ENABLE_MINDSDB:-true}"
ENABLE_COGNEE="${ENABLE_COGNEE:-true}"
ENABLE_FLOWISE="${ENABLE_FLOWISE:-true}"
ENABLE_UNSLOTH="${ENABLE_UNSLOTH:-true}"
ENABLE_CLAUDE_CODE="${ENABLE_CLAUDE_CODE:-true}"
ENABLE_METACLAW="${ENABLE_METACLAW:-true}"
ENABLE_UV="${ENABLE_UV:-true}"
ENABLE_GSTACK="${ENABLE_GSTACK:-true}"       # overlaps with Claude Code + n8n + Serena
ENABLE_ONYX="${ENABLE_ONYX:-true}"           # overlaps with Open WebUI + OpenRAG + Langflow

# Rust is auto-enabled when ZeroClaw is enabled
ENABLE_RUST="${ENABLE_RUST:-$ENABLE_ZEROCLAW}"

echo ""
echo "Feature toggles:"
for _toggle in ZEROCLAW MINDSDB COGNEE FLOWISE UNSLOTH CLAUDE_CODE METACLAW UV GSTACK ONYX RUST; do
    eval "_val=\${ENABLE_${_toggle}}"
    if [ "$_val" = "true" ]; then
        printf "  %-15s ✅ enabled\n" "$_toggle"
    else
        printf "  %-15s ⬚  disabled\n" "$_toggle"
    fi
done
echo ""

# ─────────────────── Helpers ───────────────────

step()     { echo -e "\n═══════ STEP $1: $2 ═══════\n"; }
ok()       { echo "  ✅ $1"; }
skip()     { echo "  ⏭️  $1 (already done)"; }
skip_off() { echo "  ⬚  $1 (disabled — set ENABLE_$2=true to install)"; }
warn()     { echo "  ⚠️  $1"; }
fail()     { echo "  ❌ $1"; }

TOOLS_FAILED=0

# ─────────────────── STEP 1: Node.js 22 LTS ───────────────────

step 1 "Install Node.js 22 LTS (needed for Claude Code, Flowise)"

if command -v node &>/dev/null && node --version | grep -qE '^v(2[0-9]|[3-9][0-9])'; then
    skip "Node.js $(node --version) already installed"
else
    echo "  Installing Node.js 22 via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
    ok "Node.js $(node --version) installed"
fi

# Ensure npm is up to date
sudo npm install -g npm@latest 2>/dev/null || true
ok "npm $(npm --version)"

# ─────────────────── STEP 2: Rust Toolchain ───────────────────

step 2 "Install Rust toolchain (needed for ZeroClaw)"

if [ "$ENABLE_RUST" = "true" ]; then
    if command -v rustc &>/dev/null; then
        skip "Rust $(rustc --version) already installed"
    else
        echo "  Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
        ok "Rust $(rustc --version) installed"
    fi

    # Ensure cargo is on PATH for this session
    export PATH="$HOME/.cargo/bin:$PATH"
else
    skip_off "Rust toolchain" "RUST"
fi

# ─────────────────── STEP 3: ZeroClaw ───────────────────

step 3 "Install ZeroClaw — personal AI assistant gateway"

if [ "$ENABLE_ZEROCLAW" = "true" ]; then
    ZEROCLAW_VERSION="v0.5.5"
ZEROCLAW_BIN="/usr/local/bin/zeroclaw"

if [ -f "$ZEROCLAW_BIN" ] && zeroclaw --version 2>/dev/null | grep -q "zeroclaw"; then
    skip "ZeroClaw already installed: $(zeroclaw --version 2>/dev/null || echo 'unknown')"
else
    echo "  Downloading ZeroClaw ${ZEROCLAW_VERSION} pre-built binary..."
    ZEROCLAW_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/${ZEROCLAW_VERSION}/zeroclaw-x86_64-unknown-linux-gnu.tar.gz"

    TMPDIR=$(mktemp -d)
    if curl -fsSL "$ZEROCLAW_URL" -o "$TMPDIR/zeroclaw.tar.gz"; then
        tar xzf "$TMPDIR/zeroclaw.tar.gz" -C "$TMPDIR"
        # Find the binary in the extracted files
        FOUND_BIN=$(find "$TMPDIR" -name "zeroclaw" -type f -executable 2>/dev/null | head -1)
        if [ -z "$FOUND_BIN" ]; then
            FOUND_BIN=$(find "$TMPDIR" -name "zeroclaw" -type f 2>/dev/null | head -1)
        fi
        if [ -n "$FOUND_BIN" ]; then
            sudo install -m 755 "$FOUND_BIN" "$ZEROCLAW_BIN"
            ok "ZeroClaw installed to $ZEROCLAW_BIN"
        else
            warn "ZeroClaw binary not found in archive, trying cargo install..."
            cargo install --git https://github.com/zeroclaw-labs/zeroclaw.git --locked 2>/dev/null || {
                fail "ZeroClaw install failed (both binary and cargo)"
                TOOLS_FAILED=$((TOOLS_FAILED + 1))
            }
        fi
    else
        warn "Download failed, trying cargo install..."
        cargo install --git https://github.com/zeroclaw-labs/zeroclaw.git --locked 2>/dev/null || {
            fail "ZeroClaw install failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    fi
    rm -rf "$TMPDIR"
fi

# Create default config if not exists
ZEROCLAW_CONFIG="$HOME/.zeroclaw/config.toml"
if [ ! -f "$ZEROCLAW_CONFIG" ]; then
    mkdir -p "$HOME/.zeroclaw"
    cat > "$ZEROCLAW_CONFIG" << 'TOML'
# ZeroClaw config — point at local Ollama
default_provider = "ollama"

[providers.ollama]
kind = "ollama"
base_url = "http://127.0.0.1:11434"
model = "qwen3.5:4b"
TOML
    ok "ZeroClaw config created at $ZEROCLAW_CONFIG (using local Ollama)"
fi
else
    skip_off "ZeroClaw" "ZEROCLAW"
fi

# ─────────────────── STEP 4: MindsDB (Docker) ───────────────────

step 4 "Deploy MindsDB — AI analytics query engine (Docker)"

if [ "$ENABLE_MINDSDB" = "true" ]; then
if docker ps -a --format '{{.Names}}' | grep -q '^mindsdb$'; then
    if docker ps --format '{{.Names}}' | grep -q '^mindsdb$'; then
        skip "MindsDB container already running"
    else
        echo "  Starting existing MindsDB container..."
        docker start mindsdb
        ok "MindsDB container started"
    fi
else
    echo "  Pulling and starting MindsDB Docker container..."
    docker run -d \
        --name mindsdb \
        --restart unless-stopped \
        -e MINDSDB_APIS=http,mysql \
        -p 47334:47334 \
        -p 47335:47335 \
        -v /home/mindsdb-data:/root/mindsdb_storage \
        mindsdb/mindsdb:latest || {
            fail "MindsDB Docker deployment failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    ok "MindsDB deployed — HTTP: http://localhost:47334, MySQL: localhost:47335"
fi
else
    skip_off "MindsDB" "MINDSDB"
fi

# ─────────────────── STEP 5: Cognee + Neo4j (Docker) ───────────────────

step 5 "Deploy Cognee — knowledge graph AI memory (Docker + Neo4j)"

if [ "$ENABLE_COGNEE" = "true" ]; then
# Neo4j (graph database backend for Cognee)
if docker ps -a --format '{{.Names}}' | grep -q '^neo4j$'; then
    if docker ps --format '{{.Names}}' | grep -q '^neo4j$'; then
        skip "Neo4j container already running"
    else
        docker start neo4j
        ok "Neo4j container started"
    fi
else
    echo "  Deploying Neo4j graph database..."
    docker run -d \
        --name neo4j \
        --restart unless-stopped \
        -p 7474:7474 \
        -p 7687:7687 \
        -e NEO4J_AUTH=neo4j/cognee_password_2026 \
        -e NEO4J_PLUGINS='["apoc"]' \
        -v /home/neo4j-data:/data \
        neo4j:latest || {
            fail "Neo4j Docker deployment failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    ok "Neo4j deployed — Browser: http://localhost:7474, Bolt: localhost:7687"
fi

# Cognee (Python library — install via pip, connects to Neo4j)
if command -v cognee-cli &>/dev/null || pip show cognee &>/dev/null 2>&1; then
    skip "Cognee already installed"
else
    echo "  Installing Cognee via pip..."
    pip install cognee 2>/dev/null || {
        # Try with --break-system-packages for newer Python
        pip install --break-system-packages cognee 2>/dev/null || {
            fail "Cognee pip install failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    }
    ok "Cognee installed"
fi

# Create Cognee .env if not exists
COGNEE_ENV="$HOME/.cognee/.env"
if [ ! -f "$COGNEE_ENV" ]; then
    mkdir -p "$HOME/.cognee"
    cat > "$COGNEE_ENV" << 'ENV'
# Cognee config — uses local Neo4j + Ollama
GRAPH_DATABASE_PROVIDER=neo4j
GRAPH_DATABASE_URL=bolt://localhost:7687
GRAPH_DATABASE_USERNAME=neo4j
GRAPH_DATABASE_PASSWORD=cognee_password_2026
LLM_PROVIDER=ollama
LLM_MODEL=qwen3.5:4b
LLM_ENDPOINT=http://localhost:11434
ENV
    ok "Cognee config created at $COGNEE_ENV"
fi
else
    skip_off "Cognee + Neo4j" "COGNEE"
fi

# ─────────────────── STEP 6: Flowise (Docker) ───────────────────

step 6 "Deploy Flowise — visual AI agent builder (replaces OpenRAG)"

if [ "$ENABLE_FLOWISE" = "true" ]; then
if docker ps -a --format '{{.Names}}' | grep -q '^flowise$'; then
    if docker ps --format '{{.Names}}' | grep -q '^flowise$'; then
        skip "Flowise container already running"
    else
        docker start flowise
        ok "Flowise container started"
    fi
else
    echo "  Pulling and starting Flowise Docker container..."
    docker run -d \
        --name flowise \
        --restart unless-stopped \
        -p 3000:3000 \
        -v /home/flowise-data:/root/.flowise \
        flowiseai/flowise:latest || {
            fail "Flowise Docker deployment failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    ok "Flowise deployed — UI: http://localhost:3000"
fi
else
    skip_off "Flowise" "FLOWISE"
fi

# ─────────────────── STEP 7: Unsloth Studio (Docker) ───────────────────

step 7 "Deploy Unsloth Studio — LLM inference/training UI (Docker)"

if [ "$ENABLE_UNSLOTH" = "true" ]; then
if docker ps -a --format '{{.Names}}' | grep -q '^unsloth$'; then
    if docker ps --format '{{.Names}}' | grep -q '^unsloth$'; then
        skip "Unsloth container already running"
    else
        docker start unsloth
        ok "Unsloth container started"
    fi
else
    echo "  Pulling and starting Unsloth Docker container..."
    echo "  Note: GTX 1060 (SM 6.1) supports inference/chat only — training requires RTX 30+ series"
    docker run -d \
        --name unsloth \
        --restart unless-stopped \
        -e JUPYTER_PASSWORD="unsloth2026" \
        -p 8888:8888 \
        -p 8000:8000 \
        -v /home/unsloth-data:/workspace/work \
        --gpus all \
        unsloth/unsloth:latest || {
            warn "Unsloth Docker with GPU failed, trying without GPU..."
            docker run -d \
                --name unsloth \
                --restart unless-stopped \
                -e JUPYTER_PASSWORD="unsloth2026" \
                -p 8888:8888 \
                -p 8000:8000 \
                -v /home/unsloth-data:/workspace/work \
                unsloth/unsloth:latest || {
                    fail "Unsloth Docker deployment failed (both GPU and CPU)"
                    TOOLS_FAILED=$((TOOLS_FAILED + 1))
                }
        }
    ok "Unsloth deployed — Jupyter: http://localhost:8888 (password: unsloth2026)"
fi
else
    skip_off "Unsloth Studio" "UNSLOTH"
fi

# ─────────────────── STEP 8: Claude Code (npm) ───────────────────

step 8 "Install Claude Code — Anthropic CLI coding agent"

if [ "$ENABLE_CLAUDE_CODE" = "true" ]; then
if command -v claude &>/dev/null; then
    skip "Claude Code already installed: $(claude --version 2>/dev/null || echo 'installed')"
else
    echo "  Installing Claude Code via npm..."
    sudo npm install -g @anthropic-ai/claude-code 2>/dev/null || {
        # Try without sudo
        npm install -g @anthropic-ai/claude-code 2>/dev/null || {
            fail "Claude Code npm install failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    }
    ok "Claude Code installed (requires ANTHROPIC_API_KEY to use)"
fi
else
    skip_off "Claude Code" "CLAUDE_CODE"
fi

# ─────────────────── STEP 9: MetaClaw (pip) ───────────────────

step 9 "Install MetaClaw — meta-learning LLM proxy"

if [ "$ENABLE_METACLAW" = "true" ]; then
if command -v metaclaw &>/dev/null; then
    skip "MetaClaw already installed"
else
    echo "  Installing MetaClaw via pip..."
    pip install metaclaw 2>/dev/null || \
    pip install --break-system-packages metaclaw 2>/dev/null || {
        # Try from git if PyPI doesn't have it
        echo "  PyPI failed, trying from GitHub..."
        pip install --break-system-packages git+https://github.com/aiming-lab/MetaClaw.git 2>/dev/null || {
            fail "MetaClaw install failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
    }
    ok "MetaClaw installed (run 'metaclaw setup' to configure)"
fi
else
    skip_off "MetaClaw" "METACLAW"
fi

# ─────────────────── STEP 10: uv (Python package manager) ───────────────────

step 10 "Install uv — fast Python package manager (useful for future tools)"

if [ "$ENABLE_UV" = "true" ]; then
if command -v uv &>/dev/null; then
    skip "uv already installed: $(uv --version 2>/dev/null)"
else
    echo "  Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    ok "uv $(uv --version 2>/dev/null) installed"
fi
else
    skip_off "uv" "UV"
fi

# ─────────────────── STEP 11: Gstack (npm) ───────────────────

step 11 "Install Gstack — opinionated Claude Code wrapper (15 tools)"

if [ "$ENABLE_GSTACK" = "true" ]; then
    if command -v gstack &>/dev/null || npm list -g gstack &>/dev/null 2>&1; then
        skip "Gstack already installed"
    else
        echo "  Installing Gstack via npm..."
        sudo npm install -g gstack 2>/dev/null || \
        npm install -g gstack 2>/dev/null || {
            fail "Gstack npm install failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
        ok "Gstack installed (overlaps: Claude Code, n8n, Serena)"
    fi
else
    skip_off "Gstack" "GSTACK"
fi

# ─────────────────── STEP 12: Onyx (Docker) ───────────────────

step 12 "Deploy Onyx — open source AI chat platform (Docker)"

if [ "$ENABLE_ONYX" = "true" ]; then
    if docker ps -a --format '{{.Names}}' | grep -q '^onyx$'; then
        if docker ps --format '{{.Names}}' | grep -q '^onyx$'; then
            skip "Onyx container already running"
        else
            docker start onyx
            ok "Onyx container started"
        fi
    else
        echo "  Pulling and starting Onyx Docker container..."
        echo "  Note: overlaps with Open WebUI, OpenRAG, Langflow"
        docker run -d \
            --name onyx \
            --restart unless-stopped \
            -p 3100:3000 \
            -v /home/onyx-data:/app/data \
            onyxdotapp/onyx:latest || {
                fail "Onyx Docker deployment failed"
                TOOLS_FAILED=$((TOOLS_FAILED + 1))
            }
        ok "Onyx deployed — UI: http://localhost:3100"
    fi
else
    skip_off "Onyx" "ONYX"
fi

# ─────────────────── STEP 13: UFW Firewall Rules ───────────────────

step 13 "Configure UFW firewall for new services (LAN only)"

if command -v ufw &>/dev/null; then
    LAN="192.168.0.0/24"

    # MindsDB
    [ "$ENABLE_MINDSDB" = "true" ] && {
        sudo ufw allow from "$LAN" to any port 47334 proto tcp comment "MindsDB HTTP" 2>/dev/null || true
        sudo ufw allow from "$LAN" to any port 47335 proto tcp comment "MindsDB MySQL" 2>/dev/null || true
    }

    # Neo4j (Cognee backend)
    [ "$ENABLE_COGNEE" = "true" ] && {
        sudo ufw allow from "$LAN" to any port 7474 proto tcp comment "Neo4j Browser" 2>/dev/null || true
        sudo ufw allow from "$LAN" to any port 7687 proto tcp comment "Neo4j Bolt" 2>/dev/null || true
    }

    # Flowise
    [ "$ENABLE_FLOWISE" = "true" ] && {
        sudo ufw allow from "$LAN" to any port 3000 proto tcp comment "Flowise UI" 2>/dev/null || true
    }

    # Unsloth
    [ "$ENABLE_UNSLOTH" = "true" ] && {
        sudo ufw allow from "$LAN" to any port 8888 proto tcp comment "Unsloth Jupyter" 2>/dev/null || true
        sudo ufw allow from "$LAN" to any port 8000 proto tcp comment "Unsloth API" 2>/dev/null || true
    }

    # ZeroClaw gateway (default port)
    [ "$ENABLE_ZEROCLAW" = "true" ] && {
        sudo ufw allow from "$LAN" to any port 42617 proto tcp comment "ZeroClaw Gateway" 2>/dev/null || true
    }

    # Onyx
    [ "$ENABLE_ONYX" = "true" ] && {
        sudo ufw allow from "$LAN" to any port 3100 proto tcp comment "Onyx UI" 2>/dev/null || true
    }

    ok "UFW rules added for LAN ($LAN)"
else
    warn "UFW not installed, skipping firewall config"
fi

# ─────────────────── STEP 14: Convenience Scripts ───────────────────

step 14 "Create convenience scripts and aliases"

# Status script
cat > /usr/local/bin/cf0-tools-status << 'SCRIPT'
#!/usr/bin/env bash
set -u

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

cli_version() {
    local cmd="$1"
    shift || true
    if have_cmd "$cmd"; then
        "$cmd" "$@" 2>/dev/null | head -1
    else
        echo "not installed"
    fi
}

container_state() {
    local name="$1"
    docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "missing"
}

container_ports() {
    local name="$1"
    docker port "$name" 2>/dev/null | paste -sd ',' - || echo "-"
}

status_icon() {
    case "$1" in
        running|healthy|active) printf '[OK]' ;;
        exited|dead|failed) printf '[!!]' ;;
        missing|not-installed|disabled) printf '[--]' ;;
        *) printf '[..]' ;;
    esac
}

print_cli_row() {
    local label="$1"
    local cmd="$2"
    shift 2
    local version="not installed"
    local state="not-installed"
    if have_cmd "$cmd"; then
        state="active"
        version=$("$cmd" "$@" 2>/dev/null | head -1 || echo "installed")
    fi
    printf '  %-4s %-16s %-10s %s\n' "$(status_icon "$state")" "$label" "$state" "$version"
}

print_container_row() {
    local label="$1"
    local name="$2"
    local state
    state=$(container_state "$name")
    printf '  %-4s %-16s %-10s %s\n' "$(status_icon "$state")" "$label" "$state" "$(container_ports "$name")"
}

echo "========== cf0 / ubu1 tool status =========="
printf 'Host:      %s\n' "$(hostname)"
printf 'Uptime:    %s\n' "$(uptime -p 2>/dev/null || uptime)"
printf 'Load:      %s\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
printf 'Kernel:    %s\n' "$(uname -r)"
printf 'Docker:    %s\n' "$(docker --version 2>/dev/null || echo 'not installed')"
printf 'Journald:  %s\n' "$(journalctl --disk-usage 2>/dev/null | sed 's/Archived and active journals take up //' || echo 'unavailable')"
echo ""

echo "System"
df -h /home 2>/dev/null | awk 'NR==2 {printf "  Home disk: %s used / %s total (%s free)\n", $3, $2, $4}'
free -h | awk '/Mem:/ {printf "  RAM:       %s used / %s total (%s free)\n", $3, $2, $7}'
if have_cmd nvidia-smi; then
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null | awk -F', ' '{printf "  GPU:       %s | %s / %s | util %s\n", $1, $2, $3, $4}'
else
    echo "  GPU:       none detected"
fi
echo ""

echo "CLI tools"
print_cli_row "node" node --version
print_cli_row "npm" npm --version
print_cli_row "rustc" rustc --version
print_cli_row "uv" uv --version
print_cli_row "claude" claude --version
print_cli_row "zeroclaw" zeroclaw --version
print_cli_row "metaclaw" metaclaw --version
print_cli_row "gstack" gstack --version
print_cli_row "cognee-cli" cognee-cli --version
echo ""

echo "Docker services"
printf '  %-4s %-16s %-10s %s\n' 'STAT' 'SERVICE' 'STATE' 'PORTS'
print_container_row "ollama" "ollama"
print_container_row "open-webui" "open-webui"
print_container_row "searxng" "searxng"
print_container_row "mindsdb" "mindsdb"
print_container_row "cognee" "cognee"
print_container_row "neo4j" "neo4j"
print_container_row "langflow" "langflow"
print_container_row "openrag-api" "openrag-backend"
print_container_row "openrag-ui" "openrag-frontend"
print_container_row "qdrant" "qdrant"
print_container_row "n8n" "n8n"
print_container_row "openbb" "openbb"
print_container_row "tensorlake" "tensorlake"
print_container_row "onyx" "onyx"
print_container_row "unsloth" "unsloth"
echo ""

echo "Quick commands"
echo "  journalctl -p err -b"
echo "  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo "  iotop -oPa"
echo "  nvidia-smi"
SCRIPT
chmod +x /usr/local/bin/cf0-tools-status

# Add to .bashrc if not already there
BASHRC="$HOME/.bashrc"
if ! grep -q 'cf0-tools-status' "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'ALIASES'

# === cf0 AI Tools ===
alias tools-status='cf0-tools-status'
alias zc='zeroclaw'
alias mc='metaclaw'
ALIASES
fi

ok "Convenience scripts created: cf0-tools-status, aliases"

# ─────────────────── STEP 15: API-Only Config Notes ───────────────────

step 15 "API-only models configuration notes"

cat << 'NOTES'
  ┌─────────────────────────────────────────────────────────┐
  │ API-Only Models (not installed locally — too large)      │
  ├─────────────────────────────────────────────────────────┤
  │                                                          │
  │ MiniMax M2.5:                                            │
  │   API: https://api.minimax.chat/v1                       │
  │   Docs: https://platform.minimaxi.com/                   │
  │   Add to Open WebUI as custom provider                   │
  │                                                          │
  │ Kimi K2.5:                                               │
  │   API: https://api.moonshot.cn/v1                        │
  │   Docs: https://platform.moonshot.cn/                    │
  │   Add to Open WebUI as custom provider                   │
  │                                                          │
  │ To add in Open WebUI:                                    │
  │   Settings → Connections → Add OpenAI-compatible API     │
  │                                                          │
  │ Skipped: AutoResearch (needs H100-class GPU)             │
  │ Skipped: Qwen 3.5 (already in Ollama stack)             │
  └─────────────────────────────────────────────────────────┘
NOTES

# ─────────────────── SUMMARY ───────────────────

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  cf0-llm-tools.sh COMPLETE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  Failed steps: $TOOLS_FAILED"
echo ""
echo "  Docker containers deployed:"
docker ps --format "    {{.Names}} → {{.Status}}" 2>/dev/null
echo ""
echo "  Run 'cf0-tools-status' to see full overview"
echo ""
echo "  Next steps:"
echo "    1. Set ANTHROPIC_API_KEY for Claude Code"
echo "    2. Run 'metaclaw setup' to configure MetaClaw"
echo "    3. Run 'zeroclaw onboard' to configure ZeroClaw"
echo "    4. Add API keys for MiniMax/Kimi in Open WebUI"
echo ""

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "===== cf0-llm-tools.sh finished at $TIMESTAMP ====="

exit $TOOLS_FAILED
