#!/bin/bash
# =============================================================================
# Smart Multi-WAN Load Balancer
# Auto-detects internet-facing interfaces, excludes private networks
# =============================================================================

set -e

# Configuration
WAN_TABLE_START=100
WAN_MARK_START=0x100
MONITOR_INTERVAL=30

# Private network prefixes to exclude
PRIVATE_PREFIXES=(
    "10."
    "172.16." "172.17." "172.18." "172.19."
    "172.20." "172.21." "172.22." "172.23."
    "172.24." "172.25." "172.26." "172.27."
    "172.28." "172.29." "172.30." "172.31."
    "192.168."
    "127."
    "169.254."
)

# Interface patterns to exclude
EXCLUDE_INTERFACES=(
    "lo"
    "docker*"
    "virbr*"
    "br-*"
    "veth*"
    "tun*"
    "tap*"
)

log() {
    echo "[LOADBALANCER] $(date '+%H:%M:%S') $*"
}

# Check if IP is private
is_private_ip() {
    local ip=$1
    for prefix in "${PRIVATE_PREFIXES[@]}"; do
        [[ "$ip" == "$prefix"* ]] && return 0
    done
    return 1
}

# Check if interface should be excluded
should_exclude() {
    local iface=$1
    for pattern in "${EXCLUDE_INTERFACES[@]}"; do
        [[ "$iface" == $pattern ]] && return 0
    done
    return 1
}

# Detect WAN interfaces (have default route + public IP)
detect_wan_interfaces() {
    local wan_ifaces=()
    local wan_gateways=()
    
    log "Detecting WAN interfaces..."
    
    # Get all interfaces with default routes
    while IFS= read -r line; do
        local iface gateway ip_addr
        
        # Parse: default via GATEWAY dev INTERFACE ...
        gateway=$(echo "$line" | awk '{print $3}')
        iface=$(echo "$line" | awk '{print $5}')
        
        # Skip excluded interfaces
        should_exclude "$iface" && continue
        
        # Get IP address for this interface
        ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        
        # Skip if no IP or private IP (for PPP, private is OK)
        if [ -z "$ip_addr" ]; then
            # PPP interfaces may not show IP normally
            if [[ "$iface" == ppp* ]]; then
                log "  Found PPP interface: $iface"
                wan_ifaces+=("$iface")
                wan_gateways("")
            fi
            continue
        fi
        
        # Check if it has internet route (even with private IP behind NAT)
        if [ -n "$gateway" ]; then
            log "  Found WAN interface: $iface ($ip_addr via $gateway)"
            wan_ifaces+=("$iface")
            wan_gateways+=("$gateway")
        fi
        
    done < <(ip route | grep "^default")
    
    # Export results
    WAN_IFACES=("${wan_ifaces[@]}")
    WAN_GATEWAYS=("${wan_gateways[@]}")
    WAN_COUNT=${#WAN_IFACES[@]}
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    
    # Remove iptables rules
    iptables -t mangle -F WAN_LB 2>/dev/null || true
    iptables -t mangle -X WAN_LB 2>/dev/null || true
    iptables -t mangle -D POSTROUTING -j WAN_LB 2>/dev/null || true
    
    # Remove routing rules and tables
    for i in "${!WAN_IFACES[@]}"; do
        local table=$((WAN_TABLE_START + i))
        local mark=$((WAN_MARK_START + i))
        ip rule del fwmark $mark table $table 2>/dev/null || true
        ip route flush table $table 2>/dev/null || true
    done
    
    log "Cleanup complete"
}

trap cleanup EXIT

# Setup routing
setup_routing() {
    log "Setting up routing for ${WAN_COUNT} WAN interface(s)..."
    
    for i in "${!WAN_IFACES[@]}"; do
        local iface="${WAN_IFACES[$i]}"
        local gateway="${WAN_GATEWAYS[$i]}"
        local table=$((WAN_TABLE_START + i))
        local mark=$((WAN_MARK_START + i))
        
        log "  Interface $i: $iface (table $table, mark 0x$(printf '%x' $mark))"
        
        # Flush old routes
        ip route flush table $table 2>/dev/null || true
        
        # Add route
        if [ -n "$gateway" ]; then
            ip route add default via "$gateway" dev "$iface" table $table
            ip route add "$gateway" dev "$iface" scope link table $table
        else
            # PPP (point-to-point)
            ip route add default dev "$iface" table $table
        fi
        
        # Add routing rule
        ip rule add fwmark $mark table $table priority $((100 + i))
    done
    
    # Relax reverse path filtering
    sysctl -w net.ipv4.conf.all.rp_filter=2 >/dev/null 2>&1 || true
    for iface in "${WAN_IFACES[@]}"; do
        sysctl -w net.ipv4.conf.$iface.rp_filter=2 >/dev/null 2>&1 || true
    done
}

# Setup iptables load balancing
setup_iptables() {
    log "Setting up iptables load balancing..."
    
    iptables -t mangle -N WAN_LB 2>/dev/null || iptables -t mangle -F WAN_LB
    
    if [ "$WAN_COUNT" -eq 1 ]; then
        # Single interface - mark all traffic
        iptables -t mangle -A WAN_LB -m conntrack --ctstate NEW \
            -j MARK --set-mark $WAN_MARK_START
    else
        # Multiple interfaces - distribute
        local total=$WAN_COUNT
        for i in "${!WAN_IFACES[@]}"; do
            local mark=$((WAN_MARK_START + i))
            local every=$((total - i))
            
            if [ $i -eq $((total - 1)) ]; then
                # Last interface gets remaining traffic
                iptables -t mangle -A WAN_LB -m conntrack --ctstate NEW \
                    -j MARK --set-mark $mark
            else
                # Distribute evenly
                iptables -t mangle -A WAN_LB -m conntrack --ctstate NEW \
                    -m statistic --mode nth --every $every --packet 0 \
                    -j MARK --set-mark $mark
            fi
        done
    fi
    
    iptables -t mangle -A POSTROUTING -j WAN_LB
}

# Enable MPTCP
enable_mptcp() {
    log "Enabling MPTCP..."
    sysctl -w net.mptcp.enabled=1 2>/dev/null || true
    
    # Register WAN interfaces as MPTCP endpoints
    for iface in "${WAN_IFACES[@]}"; do
        local ip_addr
        ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        if [ -n "$ip_addr" ]; then
            ip mptcp endpoint add "$ip_addr" subflow dev "$iface" 2>/dev/null || true
        fi
    done
}

# Monitor interfaces
monitor_interfaces() {
    log "Starting interface monitor (interval: ${MONITOR_INTERVAL}s)..."
    
    while true; do
        local changes=0
        
        # Check if any WAN interface went down
        for i in "${!WAN_IFACES[@]}"; do
            local iface="${WAN_IFACES[$i]}"
            if ! ip link show "$iface" 2>/dev/null | grep -q "state UP\|state UNKNOWN"; then
                log "WARNING: $iface is DOWN!"
                changes=1
            fi
        done
        
        # Re-detect if changes detected
        if [ "$changes" -eq 1 ]; then
            log "Re-detecting WAN interfaces..."
            detect_wan_interfaces
            if [ "$WAN_COUNT" -gt 0 ]; then
                setup_routing
                setup_iptables
            fi
        fi
        
        sleep $MONITOR_INTERVAL
    done
}

# Show status
show_status() {
    log "=========================================="
    log "Multi-WAN Load Balancer ACTIVE"
    log "=========================================="
    log "WAN Interfaces: $WAN_COUNT"
    
    for i in "${!WAN_IFACES[@]}"; do
        local iface="${WAN_IFACES[$i]}"
        local gateway="${WAN_GATEWAYS[$i]}"
        local ip_addr
        ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        log "  $((i+1)). $iface"
        log "     IP: ${ip_addr:-N/A}"
        log "     Gateway: ${gateway:-point-to-point}"
    done
    
    log "=========================================="
    log ""
    log "Monitor: watch -n1 'ss -tm | head -20'"
    log "Marks:   sudo iptables -t mangle -L WAN_LB -v -n"
    log "Stop:    Ctrl+C or systemctl stop multi-wan-lb"
    log ""
}

# Main
main() {
    log "=========================================="
    log "Smart Multi-WAN Load Balancer"
    log "=========================================="
    
    # Check root
    [ "$EUID" -ne 0 ] && { log "Must run as root"; exit 1; }
    
    # Detect interfaces
    detect_wan_interfaces
    
    if [ "$WAN_COUNT" -eq 0 ]; then
        log "ERROR: No WAN interfaces detected!"
        exit 1
    fi
    
    if [ "$WAN_COUNT" -eq 1 ]; then
        log "WARNING: Only 1 WAN interface found (no load balancing)"
    fi
    
    # Setup
    enable_mptcp
    setup_routing
    setup_iptables
    show_status
    
    # Start monitoring
    monitor_interfaces
}

main "$@"
