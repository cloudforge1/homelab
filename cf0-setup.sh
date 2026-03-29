#!/usr/bin/env bash
# cf0-setup.sh — Full setup for PaddlePaddle/FastDeploy dev on Ubuntu 25.10
# Run as: sudo bash /tmp/cf0-setup.sh
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
LOGFILE="/var/log/cf0-setup.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOGFILE"; }

# Bootstrap CUDA PATH so detection works in non-login shells (sudo bash ...)
if [[ -d /usr/local/cuda/bin ]]; then
    export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
fi

# ─── 0. Sanity checks ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then echo "ERROR: Run with sudo"; exit 1; fi

log "Starting cf0 setup — Ubuntu $(lsb_release -rs) on $(hostname)"

# ─── 1. Fix APT sources: HTTP → HTTPS ───────────────────────────────
log "=== Step 1: Fix APT sources (http → https) ==="
SOURCES="/etc/apt/sources.list.d/ubuntu.sources"
if grep -q 'http://' "$SOURCES" 2>/dev/null; then
    cp "$SOURCES" "${SOURCES}.bak.$(date +%s)"
    sed -i 's|http://pl.archive.ubuntu.com|https://pl.archive.ubuntu.com|g' "$SOURCES"
    sed -i 's|http://security.ubuntu.com|https://security.ubuntu.com|g' "$SOURCES"
    sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g' "$SOURCES"
    log "APT sources switched to HTTPS"
else
    log "APT sources already use HTTPS (or file not found)"
fi

# ─── 2. APT update + full upgrade ───────────────────────────────────
log "=== Step 2: apt update + upgrade ==="
apt-get update -y
apt-get -o Dpkg::Options::="--force-overwrite" dist-upgrade -y
apt-get autoremove -y

# ─── 3. Build essentials + dev tools ────────────────────────────────
log "=== Step 3: Build essentials + dev tools ==="
apt-get install -y \
    build-essential gcc g++ gfortran \
    cmake cmake-curses-gui ninja-build \
    git git-lfs curl wget \
    pkg-config autoconf automake libtool \
    unzip zip tar xz-utils \
    software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release \
    htop tmux screen tree jq ripgrep fd-find \
    net-tools iproute2 dnsutils iputils-ping \
    openssh-server \
    patchelf ccache

# ─── 4. Python ecosystem ────────────────────────────────────────────
log "=== Step 4: Python dev packages ==="
apt-get install -y \
    python3-dev python3-pip python3-venv python3-setuptools python3-wheel \
    python3-numpy python3-scipy \
    libffi-dev libssl-dev libxml2-dev libxslt1-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev libncurses-dev \
    liblzma-dev libgdbm-dev

# ─── 5. NVIDIA driver ───────────────────────────────────────────────
log "=== Step 5: NVIDIA driver ==="
if ! command -v nvidia-smi &>/dev/null; then
    # Install ubuntu-drivers-common to detect recommended driver
    apt-get install -y ubuntu-drivers-common
    
    # List available drivers
    log "Available NVIDIA drivers:"
    ubuntu-drivers list 2>&1 | tee -a "$LOGFILE" || true
    
    # Install recommended driver (typically nvidia-driver-535 or newer for GTX 1060)
    RECOMMENDED=$(ubuntu-drivers list 2>/dev/null | grep -oP 'nvidia-driver-\d+' | sort -t- -k3 -n | tail -1 || true)
    if [[ -n "$RECOMMENDED" ]]; then
        log "Installing recommended driver: $RECOMMENDED"
        apt-get install -y "$RECOMMENDED"
    else
        log "No recommended driver found via ubuntu-drivers. Installing nvidia-driver-535..."
        apt-get install -y nvidia-driver-535 || {
            log "nvidia-driver-535 not available, trying nvidia-driver-550..."
            apt-get install -y nvidia-driver-550 || {
                log "WARNING: Could not install NVIDIA driver via apt. Will try CUDA repo method."
            }
        }
    fi
else
    log "NVIDIA driver already installed: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo 'unknown')"
fi

# ─── 6. CUDA Toolkit 12.x ───────────────────────────────────────────
log "=== Step 6: CUDA Toolkit ==="
if ! command -v nvcc &>/dev/null; then
    # Add NVIDIA CUDA repository
    CUDA_KEYRING_DEB="cuda-keyring_1.1-1_all.deb"
    if [[ ! -f "/tmp/$CUDA_KEYRING_DEB" ]]; then
        wget -q "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/$CUDA_KEYRING_DEB" \
            -O "/tmp/$CUDA_KEYRING_DEB" || {
            log "WARNING: Could not download CUDA keyring for ubuntu2404, trying ubuntu2204..."
            wget -q "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/$CUDA_KEYRING_DEB" \
                -O "/tmp/$CUDA_KEYRING_DEB"
        }
    fi
    dpkg -i "/tmp/$CUDA_KEYRING_DEB"
    apt-get update -y
    
    # Install CUDA toolkit (not the full cuda meta-package which pulls driver again)
    apt-get install -y cuda-toolkit-12-6 || {
        log "cuda-toolkit-12-6 not available, trying cuda-toolkit-12-4..."
        apt-get install -y cuda-toolkit-12-4 || {
            log "WARNING: Could not install CUDA toolkit via apt."
        }
    }
    
    # Install cuDNN
    apt-get install -y libcudnn9-cuda-12 libcudnn9-dev-cuda-12 || {
        log "WARNING: cuDNN packages not available via apt."
    }
else
    log "CUDA already installed: $(nvcc --version | grep release)"
fi

# Set up CUDA environment for all users
if [[ -d /usr/local/cuda ]]; then
    cat > /etc/profile.d/cuda.sh << 'CUDA_ENV'
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
CUDA_ENV
    chmod 644 /etc/profile.d/cuda.sh
    log "CUDA environment set in /etc/profile.d/cuda.sh"
fi

# ─── 7. Intel GPU/Media drivers ─────────────────────────────────────
log "=== Step 7: Intel drivers (iGPU / media) ==="
apt-get install -y \
    intel-media-va-driver \
    intel-gpu-tools \
    vainfo \
    libva-dev libva-drm2 libva-x11-2 \
    i965-va-driver-shaders \
    mesa-utils \
    2>/dev/null || log "Some Intel packages not available (non-critical)"

# ─── 8. Additional libraries for ML/DL ──────────────────────────────
log "=== Step 8: ML/DL system libraries ==="
apt-get install -y \
    libopenblas-dev liblapack-dev \
    libhdf5-dev \
    libjpeg-dev libpng-dev libtiff-dev \
    libavcodec-dev libavformat-dev libswscale-dev \
    libprotobuf-dev protobuf-compiler \
    libgflags-dev libgoogle-glog-dev \
    graphviz \
    2>/dev/null || log "Some ML library packages not available"

# ─── 9. Docker (for FastDeploy container builds) ────────────────────
log "=== Step 9: Docker ==="
if ! command -v docker &>/dev/null; then
    # Add Docker's official GPG key and repo
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Use noble (24.04) repo since questing (25.10) may not have Docker repo yet
    UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-noble}")
    DOCKER_CODENAME="noble"  # Fallback to latest LTS
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $DOCKER_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list
    
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || {
        log "WARNING: Docker install failed. May need manual setup for Ubuntu 25.10."
    }
    
    # Add user r to docker group
    usermod -aG docker r 2>/dev/null || true
    log "Docker installed, user 'r' added to docker group"
else
    log "Docker already installed: $(docker --version)"
fi


# Configure Docker to store ALL data on RAID0 (/home) not root disk
# Root disk is only 200GB (Crucial SSD) — /home is 500GB RAID0
if command -v docker &>/dev/null && [[ ! -f /etc/docker/daemon.json ]]; then
    mkdir -p /home/docker
    cat > /etc/docker/daemon.json << 'DJSON'
{
    "data-root": "/home/docker",
    "storage-driver": "overlay2",
    "log-opts": {
        "max-size": "50m",
        "max-file": "3"
    }
}
DJSON
    systemctl restart docker 2>/dev/null || true
    log "Docker data-root → /home/docker (RAID0, 500GB)"
elif [[ -f /etc/docker/daemon.json ]]; then
    log "Docker daemon.json already exists"
fi

# NVIDIA Container Toolkit (for GPU in Docker)
if command -v docker &>/dev/null && ! dpkg -l nvidia-container-toolkit &>/dev/null; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null || true
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null 2>&1 || true
    apt-get update -y
    apt-get install -y nvidia-container-toolkit 2>/dev/null || log "WARNING: NVIDIA Container Toolkit not available"
fi

# ─── 10. NOPASSWD sudo for user r (dev machine convenience) ────────
log "=== Step 10: NOPASSWD sudo for user r ==="
if [[ ! -f /etc/sudoers.d/r-nopasswd ]]; then
    echo "r ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/r-nopasswd
    chmod 440 /etc/sudoers.d/r-nopasswd
    visudo -cf /etc/sudoers.d/r-nopasswd && log "NOPASSWD sudo configured for user r" || {
        rm -f /etc/sudoers.d/r-nopasswd
        log "WARNING: Could not configure NOPASSWD sudo"
    }
fi

# ─── 11. Miniforge (conda) for user r ──────────────────────────────
log "=== Step 11: Miniforge for user r ==="
if [[ ! -d /home/r/miniforge3 ]]; then
    MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
    wget -q "$MINIFORGE_URL" -O /tmp/miniforge.sh
    chmod +x /tmp/miniforge.sh
    # Install as user r
    su - r -c 'bash /tmp/miniforge.sh -b -p $HOME/miniforge3'
    su - r -c '$HOME/miniforge3/bin/conda init bash'
    log "Miniforge installed to /home/r/miniforge3"
else
    log "Miniforge already installed"
fi

# ─── 12. Summary ────────────────────────────────────────────────────
log "=== Setup complete ==="
log "Summary:"
log "  OS: $(lsb_release -ds)"
log "  Kernel: $(uname -r)"
log "  CPU: $(lscpu | grep 'Model name' | sed 's/Model name: *//')"
log "  RAM: $(free -h | awk '/Mem:/{print $2}')"
log "  GPU: $(lspci | grep -i nvidia | sed 's/.*: //' | head -1)"
log "  NVIDIA driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo 'NOT LOADED — reboot required')"
log "  CUDA: $(nvcc --version 2>/dev/null | grep release || echo 'not in PATH or not installed')"
log "  cuDNN: $(dpkg -l libcudnn9-cuda-12 2>/dev/null | awk '/^ii/{print $3}' || echo 'not installed')"
log "  Python: $(python3 --version)"
log "  Docker: $(docker --version 2>/dev/null || echo 'not installed')"
log "  Conda: $(/home/r/miniforge3/bin/conda --version 2>/dev/null || echo 'not installed')"

# Only show reboot warning if nvidia-smi fails (driver not loaded)
if ! nvidia-smi &>/dev/null; then
    log ""
    log "⚠️  REBOOT REQUIRED for NVIDIA driver to load!"
    log "   Run: sudo reboot"
else
    log ""
    log "✅ All components verified — no reboot needed."
fi
log ""
log "Next steps as user r:"
log "   1. nvidia-smi                    # verify GPU"
log "   2. conda create -n fd python=3.10 -y  # create FastDeploy env"
log "   3. conda activate fd"
log "   4. pip install paddlepaddle-gpu   # install PaddlePaddle with GPU"
log "   5. pip install -r FastDeploy/requirements.txt  # FastDeploy deps"
log ""
log "Full log: $LOGFILE"
