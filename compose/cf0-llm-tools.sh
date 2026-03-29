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

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

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
ENABLE_GSTACK="${ENABLE_GSTACK:-false}"   # disabled — overlaps with Claude Code; set true to re-enable
ENABLE_ONYX="${ENABLE_ONYX:-false}"      # disabled — overlaps with Open WebUI / OpenRAG; set true to re-enable

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

# ─────────────────── STEP 13: docling-serve (systemd) ───────────────────

step 13 "Install docling-serve — IBM document conversion API (port 5001)"

DOCLING_PORT=5001
DOCLING_UNIT="/etc/systemd/system/docling-serve.service"

if systemctl is-active --quiet docling-serve 2>/dev/null; then
    skip "docling-serve systemd service already running"
else
    # Install the package
    if python3 -c 'import docling_serve' &>/dev/null 2>&1; then
        skip "docling-serve Python package already installed"
    else
        echo "  Installing docling-serve via pip (IBM Research)..."
        pip install docling-serve 2>/dev/null || \
        pip install --break-system-packages docling-serve 2>/dev/null || {
            fail "docling-serve pip install failed"
            TOOLS_FAILED=$((TOOLS_FAILED + 1))
        }
        ok "docling-serve package installed"
    fi

    # Resolve the binary path
    DOCLING_BIN=$(command -v docling-serve 2>/dev/null || echo "$HOME/.local/bin/docling-serve")

    # Write systemd unit (idempotent)
    sudo tee "$DOCLING_UNIT" > /dev/null << UNIT
[Unit]
Description=Docling document conversion REST server
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$DOCLING_BIN run --host 0.0.0.0 --port $DOCLING_PORT
Restart=on-failure
RestartSec=10
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
UNIT

    sudo systemctl daemon-reload
    sudo systemctl enable --now docling-serve 2>/dev/null || {
        warn "docling-serve systemd enable failed — check: systemctl status docling-serve"
        TOOLS_FAILED=$((TOOLS_FAILED + 1))
    }
    ok "docling-serve enabled (http://localhost:${DOCLING_PORT}/docs)"
fi

# ─────────────────── STEP 14: UFW Firewall Rules ───────────────────

step 14 "Configure UFW firewall for new services (LAN only)"

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

    # docling-serve
    sudo ufw allow from "$LAN" to any port 5001 proto tcp comment "docling-serve API" 2>/dev/null || true

    # Scrutiny SMART monitoring UI
    sudo ufw allow from "$LAN" to any port 7786 proto tcp comment "Scrutiny UI" 2>/dev/null || true

    # OpenSpace skill manager
    sudo ufw allow from "$LAN" to any port 7788 proto tcp comment "OpenSpace dashboard" 2>/dev/null || true

    ok "UFW rules added for LAN ($LAN)"
else
    warn "UFW not installed, skipping firewall config"
fi

# ─────────────────── STEP 15: Convenience Scripts ───────────────────

step 15 "Create convenience scripts and aliases"

# Status script
cat > /usr/local/bin/cf0-tools-status << 'SCRIPT'
#!/usr/bin/env bash
set -u

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SHOW_BENCH=0
[ "${1:-}" = "--bench" ] || [ "${1:-}" = "--llm-bench" ] && SHOW_BENCH=1

# ── Colors (auto-detect terminal) ──
if [ -t 1 ]; then
    G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; C=$'\033[36m'
    B=$'\033[1m'; D=$'\033[2m'; DI=$'\033[90m'; N=$'\033[0m'
else
    G=''; R=''; Y=''; C=''; B=''; D=''; DI=''; N=''
fi

have_cmd() { command -v "$1" >/dev/null 2>&1; }

python_cmd() {
    local c
    for c in \
        "$HOME/miniforge3/envs/fd/bin/python3" \
        "$HOME/miniforge3/bin/python3" \
        "$(command -v python3 2>/dev/null || true)"
    do
        [ -n "$c" ] && [ -x "$c" ] && printf '%s\n' "$c" && return
    done
    printf 'python3\n'
}

container_state() {
    local s
    if s=$(docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null); then
        printf '%s\n' "$s"
    else
        printf 'missing\n'
    fi
}

http_probe() {
    curl -o /dev/null -sS -L --max-time 4 -w '%{http_code}|%{time_total}' "$1" 2>/dev/null || echo '000|timeout'
}

bytes_to_gib() { awk -v b="$1" 'BEGIN {printf "%.1fG", b / 1073741824}'; }

# ── Display helpers ──
section() {
    printf '\n %s%s%s\n' "$B" "$1" "$N"
    printf ' %s%s%s\n' "$DI" "$(printf '%.0s─' $(seq 1 72))" "$N"
}

cli_row() {
    local label="$1" cmd="$2" desc="$3"
    shift 3
    local ver="—" ico="${R}✗${N}"
    if have_cmd "$cmd"; then
        ver=$("$cmd" "$@" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' || echo "installed")
        # strip command-name prefix and parenthetical build info
        ver=$(echo "$ver" | sed "s/^${cmd} //" | sed 's/ (.*//')
        [ "${#ver}" -gt 26 ] && ver="${ver:0:26}…"
        ico="${G}✓${N}"
    fi
    local line
    line=$(printf '%-15s %-28s %s' "$label" "$ver" "$desc")
    echo "  ${ico} ${line}"
}

pkg_row() {
    local label="$1" kind="$2" pkg="$3" desc="$4"
    local ver="" ico
    if [ "$kind" = "pip" ]; then
        ver=$($(python_cmd) -c 'import importlib.metadata as m, sys; print(m.version(sys.argv[1]))' "$pkg" 2>/dev/null || true)
    elif [ "$kind" = "npm" ]; then
        ver=$(npm list -g --depth=0 --prefix "$HOME/.local" "$pkg" 2>/dev/null | grep "${pkg}@" | head -1 | sed "s/.*${pkg}@//")
    fi
    if [ -n "$ver" ]; then
        ico="${G}✓${N}"
    else
        ico="${R}✗${N}"; ver="—"
    fi
    local line
    line=$(printf '%-15s %-28s %s' "$label" "$ver" "$desc")
    echo "  ${ico} ${line}"
}

svc_row() {
    local label="$1" container="$2" port="$3" health_url="$4" desc="$5"
    local state ico http_code
    state=$(container_state "$container")
    case "$state" in
        running) ico="${G}✓${N}" ;;
        *)       ico="${R}✗${N}" ;;
    esac
    http_code="—"
    if [ "$state" = "running" ] && [ -n "$health_url" ]; then
        local result code
        result=$(http_probe "$health_url")
        code=${result%%|*}
        [ "$code" != "000" ] && http_code="$code" || http_code="err"
    fi
    local line
    line=$(printf '%-15s %-9s %-8s %-5s %s' "$label" "$state" "${port:---}" "$http_code" "$desc")
    echo "  ${ico} ${line}"
}

opt_svc_row() {
    local label="$1" container="$2" port="$3" desc="$4"
    local state
    state=$(container_state "$container")
    local line
    case "$state" in
        missing)
            line=$(printf '%-15s %-9s %-8s %-5s %s' "$label" "off" "${port:---}" "—" "${DI}${desc}${N}")
            echo "  ${DI}–${N} ${line}"
            ;;
        running)
            svc_row "$label" "$container" "$port" "" "$desc"
            ;;
        *)
            line=$(printf '%-15s %-9s %-8s %-5s %s' "$label" "stopped" "${port:---}" "—" "$desc")
            echo "  ${Y}!${N} ${line}"
            ;;
    esac
}

native_svc_row() {
    # Like svc_row but checks systemd unit state instead of Docker container state.
    local label="$1" unit="$2" port="$3" health_url="$4" desc="$5"
    local state ico http_code
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        state="running"; ico="${G}✓${N}"
    elif systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        state="stopped"; ico="${Y}!${N}"
    else
        state="missing"; ico="${R}✗${N}"
    fi
    http_code="—"
    if [ "$state" = "running" ] && [ -n "$health_url" ]; then
        local result code
        result=$(http_probe "$health_url")
        code=${result%%|*}
        [ "$code" != "000" ] && http_code="$code" || http_code="err"
    fi
    local line
    line=$(printf '%-15s %-9s %-8s %-5s %s' "$label" "$state" "${port:---}" "$http_code" "$desc")
    echo "  ${ico} ${line}"
}

# ── Ollama ──
ollama_models_json() {
    curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags 2>/dev/null
}

ollama_loaded_json() {
    curl -fsS --max-time 5 http://127.0.0.1:11434/api/ps 2>/dev/null
}

print_ollama_models() {
    local json="$1"
    echo "$json" | jq -r '.models | sort_by(.size) | .[] | "\(.name)|\(.details.parameter_size // "?")|\(.details.quantization_level // "?")|\(.size)"' | while IFS='|' read -r name params quant size; do
        printf '  %-24s %-8s %-10s %s\n' "$name" "$params" "$quant" "$(bytes_to_gib "$size")"
    done
}

run_ollama_bench() {
    local model="$1"
    local payload result eval_count eval_duration total_duration tok_s
    payload=$(jq -nc --arg model "$model" '{model: $model, prompt: "Reply with a short health check sentence.", stream: false, options: {num_predict: 24, temperature: 0}}')
    result=$(curl -fsS --max-time 90 http://127.0.0.1:11434/api/generate -d "$payload" 2>/dev/null || true)
    eval_count=$(echo "$result" | jq -r '.eval_count // 0' 2>/dev/null || echo 0)
    if [ -z "$result" ] || [ "$eval_count" = "0" ]; then
        local embed_payload embed_result start_ns end_ns elapsed_s dims
        embed_payload=$(jq -nc --arg model "$model" '{model: $model, input: "health check embedding benchmark"}')
        start_ns=$(date +%s%N)
        embed_result=$(curl -fsS --max-time 90 http://127.0.0.1:11434/api/embed -d "$embed_payload" 2>/dev/null || true)
        end_ns=$(date +%s%N)
        if [ -z "$embed_result" ]; then
            printf '  %-24s %s\n' "$model" "${R}failed${N}"
            return
        fi
        elapsed_s=$(awk -v start="$start_ns" -v end="$end_ns" 'BEGIN { printf "%.2f", (end - start) / 1000000000 }')
        dims=$(echo "$embed_result" | jq -r 'if (.embedding // empty) != empty then (.embedding | length) else ((.embeddings[0] // []) | length) end' 2>/dev/null || echo 0)
        printf '  %-24s embed     %s dims     %ss\n' "$model" "$dims" "$elapsed_s"
        return
    fi
    eval_duration=$(echo "$result" | jq -r '.eval_duration // 0')
    total_duration=$(echo "$result" | jq -r '.total_duration // 0')
    tok_s=$(awk -v n="$eval_count" -v d="$eval_duration" 'BEGIN { if (d > 0) printf "%.1f", n / (d / 1000000000); else printf "0.0" }')
    local total_s
    total_s=$(awk -v n="$total_duration" 'BEGIN { printf "%.1f", n / 1000000000 }')
    printf '  %-24s %s tok/s    %s tokens   %ss\n' "$model" "$tok_s" "$eval_count" "$total_s"
}

run_all_ollama_benches() {
    local json="$1"
    echo "$json" | jq -r '.models | sort_by(.size) | .[].name' | while IFS= read -r model; do
        [ -n "$model" ] || continue
        run_ollama_bench "$model"
    done
}

# ═══════════════════════════════════════════════════════
#                        OUTPUT
# ═══════════════════════════════════════════════════════

printf '\n%s ═══════════════════════ cf0 tool status ═══════════════════════%s\n' "$B" "$N"

# ── System ──
section "System"
_host=$(hostname)
_up=$(uptime -p 2>/dev/null || uptime)
_load=$(cut -d' ' -f1-3 /proc/loadavg)
_kern=$(uname -r)
_dock=$(docker --version 2>/dev/null | sed 's/Docker version //;s/,.*//' || echo 'N/A')
_jour=$(journalctl --disk-usage 2>/dev/null | sed 's/.*take up //;s/ .*//' || echo 'N/A')
printf '  %-9s %-26s %-9s %s\n' "Host" "$_host" "Kernel" "$_kern"
printf '  %-9s %-26s %-9s %s\n' "Uptime" "$_up" "Docker" "$_dock"
printf '  %-9s %-26s %-9s %s\n' "Load" "$_load" "Journal" "$_jour"
echo ""
df -h /home 2>/dev/null | awk 'NR==2 {printf "  %-9s %s / %s (%s free)\n", "Disk", $3, $2, $4}'
free -h | awk '/Mem:/ {printf "  %-9s %s / %s (%s free)\n", "RAM", $3, $2, $7}'
if have_cmd nvidia-smi; then
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null | \
        awk -F', ' '{printf "  %-9s %s · %s / %s · util %s\n", "GPU", $1, $2, $3, $4}'
else
    printf '  %-9s %s\n' "GPU" "none detected"
fi

# ── CLI tools ──
section "CLI Tools"
printf '  %s  %-15s %-28s %s\n' " " "NAME" "VERSION" "DESCRIPTION"
cli_row "node"     node     "JS runtime"                   --version
cli_row "npm"      npm      "Node package manager"         --version
cli_row "rustc"    rustc    "Rust compiler"                --version
cli_row "uv"       uv       "Fast Python pkg manager"      --version
cli_row "claude"   claude   "AI coding agent (Anthropic)"  --version
cli_row "zeroclaw" zeroclaw "AI gateway → Ollama"          --help
pkg_row "metaclaw" pip metaclaw   "Agent orchestration"
pkg_row "cognee"   pip cognee     "Knowledge graph memory"

# ── Services (merged with health probes) ──
section "Services"
printf '  %s  %-15s %-9s %-8s %-5s %s\n' " " "NAME" "STATE" "PORT" "HTTP" "DESCRIPTION"
svc_row "ollama"      "ollama"           ":11434" "http://127.0.0.1:11434/api/tags" "LLM inference server"
svc_row "open-webui"  "open-webui"       ":8080"  "http://127.0.0.1:8080/"          "ChatGPT-style chat UI"
svc_row "searxng"     "searxng"          ":8081"  "http://127.0.0.1:8081/"          "Private metasearch"
svc_row "mindsdb"     "mindsdb"          ":47334" "http://127.0.0.1:47334/"         "SQL + AI predictions"
svc_row "cognee"      "cognee"           ":8000"  ""                                "Knowledge graph memory"
svc_row "neo4j"       "neo4j"            ":7474"  "http://127.0.0.1:7474/"          "Graph database"
svc_row "langflow"    "langflow"         ":7860"  ""                                "Visual AI workflows"
svc_row "openrag-api" "openrag-backend"  "--"     ""                                "RAG API backend"
svc_row "openrag-ui"  "openrag-frontend" ":3000"  ""                                "Document Q&A"
svc_row "qdrant"      "qdrant"           ":6333"  "http://127.0.0.1:6333/healthz"   "Vector DB for RAG"
svc_row "n8n"         "n8n"              ":5679"  "http://127.0.0.1:5679/"          "Workflow automation"
svc_row "openbb"      "openbb"           ":6900"  "http://127.0.0.1:6900/"          "Financial data terminal"
svc_row "tensorlake"  "tensorlake"       ":8900"  "http://127.0.0.1:8900/"          "Document extraction"
svc_row "scrutiny"    "scrutiny"         ":7786"  "http://127.0.0.1:7786/api/health" "SMART disk monitoring"
svc_row "openspace"   "openspace"        ":7788"  "http://127.0.0.1:7788/health"     "Skill manager (read-only)"
native_svc_row "docling-serve" "docling-serve" ":5001" "http://127.0.0.1:5001/docs"  "Document conversion API"
opt_svc_row "onyx"    "onyx"             ":3100"  "AI workspace (enable to deploy)"
opt_svc_row "unsloth" "unsloth"          ":8888"  "LLM fine-tuning (enable to deploy)"

# ── Ollama models ──
section "Ollama Models"
if have_cmd jq; then
    OLLAMA_JSON=$(ollama_models_json)
    if [ -n "$OLLAMA_JSON" ]; then
        _nmod=$(echo "$OLLAMA_JSON" | jq '.models | length')
        _nlod=$(ollama_loaded_json | jq '.models | length' 2>/dev/null || echo 0)
        printf '  %s models · %s loaded\n\n' "$_nmod" "$_nlod"
        printf '  %-24s %-8s %-10s %s\n' 'MODEL' 'PARAMS' 'QUANT' 'SIZE'
        print_ollama_models "$OLLAMA_JSON"
        if [ "$SHOW_BENCH" = "1" ]; then
            section "Benchmarks"
            printf '  %-24s %-10s %-12s %s\n' 'MODEL' 'SPEED' 'TOKENS' 'TOTAL'
            run_all_ollama_benches "$OLLAMA_JSON"
        fi
    else
        echo "  ${R}✗${N} Ollama API not responding"
    fi
else
    echo "  ${DI}jq not installed — cannot list models${N}"
fi

# ── Reference ──
section "Reference"
printf '  %s%sWeb UIs%s\n' "$B" "$C" "$N"
printf '  %-28s %s\n' \
    "http://cf0:8080"           "Open WebUI — LLM chat" \
    "http://cf0:8081"           "SearXNG — private search" \
    "http://cf0:3000"           "OpenRAG — document Q&A" \
    "http://cf0:7860"           "Langflow — visual AI flows" \
    "http://cf0:5679"           "n8n — workflow automation" \
    "http://cf0:47334"          "MindsDB — SQL + AI" \
    "http://cf0:7474"           "Neo4j — graph browser" \
    "http://cf0:6333/dashboard" "Qdrant — vector DB" \
    "http://cf0:6900"           "OpenBB — financial data" \
    "http://cf0:8900"           "Tensorlake — doc extraction" \
    "http://cf0:7786"           "Scrutiny — SMART disk health" \
    "http://cf0:7788"           "OpenSpace — AI skill manager" \
    "http://cf0:5001/docs"      "docling-serve — document API"
echo ""
printf '  %s%sCommands%s\n' "$B" "$C" "$N"
printf '  %-32s %s\n' \
    "tools-status"              "This dashboard" \
    "tools-bench"               "Benchmark all Ollama models" \
    "ollama run qwen3.5:4b"     "Chat with a local model" \
    "ollama list"               "Show downloaded models" \
    "claude"                    "Start Claude AI coding agent" \
    "zc 'prompt'"               "ZeroClaw → route to Ollama" \
    "docker logs -f <svc>"      "Follow service logs" \
    "docker restart <svc>"      "Restart a service" \
    "nvidia-smi"                "GPU memory / utilization"
echo ""
SCRIPT
chmod +x /usr/local/bin/cf0-tools-status

# Add to .bashrc if not already there
BASHRC="$HOME/.bashrc"
if ! grep -q 'cf0-tools-status' "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'ALIASES'

# === cf0 AI Tools ===
alias tools-status='cf0-tools-status'
alias tools-bench='cf0-tools-status --bench'
alias zc='zeroclaw'
alias mc='metaclaw'
ALIASES
fi

ok "Convenience scripts created: cf0-tools-status, aliases"

# ─────────────────── STEP 16: API-Only Config Notes ───────────────────

step 16 "API-only models configuration notes"

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
