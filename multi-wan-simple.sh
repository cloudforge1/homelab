#!/bin/bash
# =============================================================================
# Simple Multi-WAN Load Balancer for Laptop
# Uses policy routing + connection marking for per-connection distribution
# =============================================================================

set -e

WIFI_IF="wlp0s20f3"
PPP_IF="ppp0"
WIFI_TABLE=100
PPP_TABLE=101
WIFI_MARK=0x100
PPP_MARK=0x101

log() {
    echo "[LOADBALANCER] $(date '+%H:%M:%S') $*"
}

cleanup() {
    log "Cleaning up..."
    iptables -t mangle -F WAN_LB 2>/dev/null || true
    iptables -t mangle -X WAN_LB 2>/dev/null || true
    ip rule del fwmark $WIFI_MARK table $WIFI_TABLE 2>/dev/null || true
    ip rule del fwmark $PPP_MARK table $PPP_TABLE 2>/dev/null || true
    ip route flush table $WIFI_TABLE 2>/dev/null || true
    ip route flush table $PPP_TABLE 2>/dev/null || true
}

trap cleanup EXIT

# Enable MPTCP
sysctl -w net.mptcp.enabled=1 2>/dev/null || true

# Setup routing tables
log "Setting up routing tables..."

# Get gateways
WIFI_GW=$(ip route | grep "default.*$WIFI_IF" | awk '{print $3}' | head -1)
log "WiFi gateway: $WIFI_GW"

# PPP is point-to-point, no gateway
log "PPP interface: $PPP_IF (point-to-point)"

# Flush old
ip route flush table $WIFI_TABLE 2>/dev/null || true
ip route flush table $PPP_TABLE 2>/dev/null || true

# Add routes
if [ -n "$WIFI_GW" ]; then
    ip route add default via "$WIFI_GW" dev "$WIFI_IF" table $WIFI_TABLE
fi
ip route add default dev "$PPP_IF" table $PPP_TABLE

# Setup iptables marks - per-connection round-robin
log "Setting up connection marking..."

iptables -t mangle -N WAN_LB 2>/dev/null || iptables -t mangle -F WAN_LB

# Mark new connections alternately
# Using conntrack for per-connection (not per-packet) distribution
iptables -t mangle -A WAN_LB -m conntrack --ctstate NEW \
    -m statistic --mode nth --every 2 --packet 0 \
    -j MARK --set-mark $WIFI_MARK

iptables -t mangle -A WAN_LB -m conntrack --ctstate NEW \
    -m statistic --mode nth --every 1 --packet 0 \
    -j MARK --set-mark $PPP_MARK

iptables -t mangle -A POSTROUTING -j WAN_LB

# Setup rules
log "Setting up routing rules..."
ip rule add fwmark $WIFI_MARK table $WIFI_TABLE priority 100
ip rule add fwmark $PPP_MARK table $PPP_TABLE priority 101

# Relax reverse path filtering
sysctl -w net.ipv4.conf.all.rp_filter=2 2>/dev/null || true
sysctl -w net.ipv4.conf.$WIFI_IF.rp_filter=2 2>/dev/null || true
sysctl -w net.ipv4.conf.$PPP_IF.rp_filter=2 2>/dev/null || true

log "=========================================="
log "Load Balancer ACTIVE"
log "WiFi ($WIFI_IF): $WIFI_GW"
log "PPP  ($PPP_IF): point-to-point"
log "=========================================="
log ""
log "Testing connectivity..."

# Test both paths
test_connection() {
    local mark=$1
    local name=$2
    local result
    result=$(ip netns exec test-ns-$name ping -c 2 -W 2 8.8.8.8 2>&1 | tail -2 || echo "FAILED")
    echo "  $name: $result"
}

# Quick test
ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && log "Internet: OK" || log "Internet: CHECK ROUTES"

log ""
log "Monitor with: watch -n1 'cat /proc/net/nf_conntrack | wc -l; ss -tm'"
log "Stop with: systemctl stop multi-wan-lb"

# Keep running
while true; do
    sleep 30
    
    # Check interfaces
    if ! ip link show "$WIFI_IF" | grep -q "state UP"; then
        log "WiFi DOWN - rerouting via PPP"
        iptables -t mangle -F WAN_LB
        iptables -t mangle -A WAN_LB -j MARK --set-mark $PPP_MARK
    fi
    
    if ! ip link show "$PPP_IF" | grep -q "state UNKNOWN\|state UP"; then
        log "PPP DOWN - rerouting via WiFi"
        iptables -t mangle -F WAN_LB
        iptables -t mangle -A WAN_LB -j MARK --set-mark $WIFI_MARK
    fi
done
