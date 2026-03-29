#!/usr/bin/env bash
# cf0-vagrant-setup.sh — Install Vagrant + libvirt for Windows VM testing
# Run as: sudo bash /opt/cf0-scripts/cf0-vagrant-setup.sh
# Purpose: Set up Vagrant with libvirt/QEMU/KVM to run Windows Server 2022 VMs
#          for FastDeploy Windows compilation guard testing (task-045/046)
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
LOGFILE="/var/log/cf0-vagrant-setup.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOGFILE"; }

if [[ $EUID -ne 0 ]]; then echo "ERROR: Run with sudo"; exit 1; fi

log "Starting Vagrant + libvirt setup on $(hostname)"

# ─── 1. KVM/QEMU prerequisites ──────────────────────────────────────
log "=== Step 1: KVM/QEMU prerequisites ==="
apt-get update -y
apt-get install -y \
    qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients \
    virtinst bridge-utils cpu-checker \
    libvirt-dev libxml2-dev libxslt1-dev zlib1g-dev ruby-dev \
    ebtables dnsmasq-base \
    nfs-kernel-server

# Verify KVM works
if kvm-ok 2>&1 | grep -q "can be used"; then
    log "KVM acceleration: OK"
else
    log "WARNING: KVM acceleration not available — VMs will be very slow"
fi

# ─── 2. Enable and start libvirtd ────────────────────────────────────
log "=== Step 2: Enable libvirtd ==="
systemctl enable --now libvirtd
systemctl enable --now virtlogd

# Add user r to libvirt/kvm groups
usermod -aG libvirt r 2>/dev/null || true
usermod -aG kvm r 2>/dev/null || true
log "User 'r' added to libvirt and kvm groups"

# ─── 3. Install Vagrant ─────────────────────────────────────────────
log "=== Step 3: Install Vagrant ==="
if command -v vagrant &>/dev/null; then
    log "Vagrant already installed: $(vagrant --version)"
else
    # Direct .deb download — HashiCorp APT repo doesn't support Ubuntu 25.10 (questing)
    VAGRANT_VER=$(curl -sS https://checkpoint-api.hashicorp.com/v1/check/vagrant | python3 -c "import sys,json; print(json.load(sys.stdin)['current_version'])")
    log "Downloading Vagrant ${VAGRANT_VER}..."
    wget -q "https://releases.hashicorp.com/vagrant/${VAGRANT_VER}/vagrant_${VAGRANT_VER}-1_amd64.deb" -O /tmp/vagrant.deb
    dpkg -i /tmp/vagrant.deb
    rm -f /tmp/vagrant.deb
    log "Vagrant installed: $(vagrant --version)"
fi

# ─── 4. Install vagrant-libvirt plugin ───────────────────────────────
log "=== Step 4: vagrant-libvirt plugin ==="
# Install as user r (plugins are per-user)
if su - r -c 'vagrant plugin list' 2>/dev/null | grep -q vagrant-libvirt; then
    log "vagrant-libvirt plugin already installed"
else
    su - r -c 'vagrant plugin install vagrant-libvirt' || {
        log "WARNING: vagrant-libvirt plugin install failed — may need manual retry as user r"
    }
    log "vagrant-libvirt plugin installed"
fi

# ─── 5. Configure libvirt storage on RAID0 (/home) ──────────────────
log "=== Step 5: Configure libvirt storage pool on RAID0 ==="
# Default pool stores images on root disk — move to RAID0 /home for space
POOL_DIR="/home/libvirt-images"
mkdir -p "$POOL_DIR"
chown root:root "$POOL_DIR"
chmod 711 "$POOL_DIR"

# Check if custom pool already exists
if virsh pool-info vagrant-images &>/dev/null; then
    log "vagrant-images pool already exists"
else
    virsh pool-define-as vagrant-images dir --target "$POOL_DIR" || true
    virsh pool-build vagrant-images 2>/dev/null || true
    virsh pool-start vagrant-images 2>/dev/null || true
    virsh pool-autostart vagrant-images || true
    log "Created libvirt pool 'vagrant-images' at $POOL_DIR"
fi

# Also redirect the default pool if it points to root disk
DEFAULT_POOL_PATH=$(virsh pool-dumpxml default 2>/dev/null | grep -oP '(?<=<path>).*(?=</path>)' || echo "/var/lib/libvirt/images")
if [[ "$DEFAULT_POOL_PATH" == "/var/lib/libvirt/images" ]]; then
    # Stop default pool, redirect to RAID0, restart
    virsh pool-destroy default 2>/dev/null || true
    virsh pool-delete default 2>/dev/null || true
    virsh pool-undefine default 2>/dev/null || true
    
    mkdir -p /home/libvirt-default
    chmod 711 /home/libvirt-default
    
    virsh pool-define-as default dir --target /home/libvirt-default || true
    virsh pool-build default 2>/dev/null || true
    virsh pool-start default 2>/dev/null || true
    virsh pool-autostart default || true
    log "Redirected default libvirt pool to /home/libvirt-default (RAID0)"
fi

# ─── 6. Configure Vagrant to use libvirt by default ──────────────────
log "=== Step 6: Configure Vagrant defaults ==="
# Set VAGRANT_DEFAULT_PROVIDER for user r
BASHRC="/home/r/.bashrc"
if ! grep -q 'VAGRANT_DEFAULT_PROVIDER' "$BASHRC" 2>/dev/null; then
    echo '' >> "$BASHRC"
    echo '# Vagrant — use libvirt provider (KVM)' >> "$BASHRC"
    echo 'export VAGRANT_DEFAULT_PROVIDER=libvirt' >> "$BASHRC"
    log "Set VAGRANT_DEFAULT_PROVIDER=libvirt in .bashrc"
fi

# Also set VAGRANT_HOME on RAID0 to keep boxes off root disk
if ! grep -q 'VAGRANT_HOME' "$BASHRC" 2>/dev/null; then
    echo 'export VAGRANT_HOME=/home/r/.vagrant.d' >> "$BASHRC"
    log "Set VAGRANT_HOME=/home/r/.vagrant.d (RAID0)"
fi

# ─── 7. Firewall: allow libvirt NAT ─────────────────────────────────
log "=== Step 7: Firewall for libvirt ==="
if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
    ufw allow in on virbr0 || true
    log "UFW: allowed traffic on virbr0"
else
    log "UFW not active — no firewall changes needed"
fi

# ─── 8. Clone vagrant-win test files ────────────────────────────────
log "=== Step 8: Set up vagrant-win test directory ==="
FD_WIN_DIR="/home/r/vagrant-win"
if [[ ! -d "$FD_WIN_DIR" ]]; then
    mkdir -p "$FD_WIN_DIR"
    chown r:r "$FD_WIN_DIR"
    log "Created $FD_WIN_DIR — SCP Vagrantfile + test scripts from local machine"
    log "  scp -r vagrant-win/* r@cf0:~/vagrant-win/"
else
    log "$FD_WIN_DIR already exists"
fi

# ─── 9. Summary ─────────────────────────────────────────────────────
log "=== Setup complete ==="
log "Summary:"
log "  KVM: $(kvm-ok 2>&1 | head -1)"
log "  QEMU: $(qemu-system-x86_64 --version 2>/dev/null | head -1 || echo 'not found')"
log "  libvirtd: $(systemctl is-active libvirtd)"
log "  Vagrant: $(vagrant --version 2>/dev/null || echo 'not installed')"
log "  vagrant-libvirt: $(su - r -c 'vagrant plugin list 2>/dev/null' | grep vagrant-libvirt || echo 'not installed')"
log "  Storage pool: $(virsh pool-info default 2>/dev/null | grep -oP 'State:\s+\K.*' || echo 'unknown')"
log "  Vagrant boxes dir: /home/r/.vagrant.d (RAID0)"
log "  VM images dir: /home/libvirt-default (RAID0)"
log ""
log "Next steps:"
log "  1. SCP test files:  scp -r vagrant-win/* r@cf0:~/vagrant-win/"
log "  2. SSH as user r:   ssh r@cf0"
log "  3. Start VM:        cd ~/vagrant-win && vagrant up"
log "  4. Run tests:       vagrant winrm -c 'powershell -ExecutionPolicy Bypass -File C:\\Users\\vagrant\\run_test.ps1 all'"
log ""
log "First 'vagrant up' downloads Windows Server 2022 (~6GB) + installs MSVC (~30 min total)"
log "Subsequent starts are ~2 min."
log ""
log "Full log: $LOGFILE"
