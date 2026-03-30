#!/bin/bash
# =============================================================================
# Multi-WAN Load Balancer for Laptop
# Dynamically distributes traffic across WiFi + Cellular (PPP) connections
# =============================================================================
# Features:
#   - Per-connection load balancing (round-robin)
#   - Dynamic speed monitoring
#   - Automatic failover
#   - Marks packets for policy routing
# =============================================================================

set -e

# Configuration
WIFI_IF="wlp0s20f3"
PPP_IF="ppp0"
WIFI_TABLE=100
PPP_TABLE=101
WIFI_MARK=100
PPP_MARK=101
MONITOR_INTERVAL=30  # seconds

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/multi-wan-lb.log
}

# Check if interfaces are up
check_interfaces() {
    local wifi_up=0
    local ppp_up=0
    
    ip link show "$WIFI_IF" | grep -q "state UP" && wifi_up=1
    ip link show "$PPP_IF" | grep -q "state UNKNOWN\|state UP" && ppp_up=1
    
    echo "$wifi_up $ppp_up"
}

# Measure connection speed (simple latency + download test)
measure_speed() {
    local interface=$1
    local result
    
    # Quick latency test to gateway
    local gateway
    gateway=$(ip route | grep "default.*$interface" | awk '{print $3}' | head -1)
    
    if [ -n "$gateway" ]; then
        local ping_time
        ping_time=$(ping -c 3 -W 1 -I "$interface" "$gateway" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "999")
        
        # Quick download test (1MB from Cloudflare)
        local download_speed
        download_speed=$(timeout 10 curl -s -o /dev/null -w "%{speed_download}" \
            --interface "$interface" \
            "https://speed.cloudflare.com/__down?bytes=1000000" 2>/dev/null || echo "0")
        
        # Score: lower latency + higher bandwidth = better
        # Normalize: latency (ms) inverted, bandwidth (bytes/s) normalized
        echo "$ping_time $download_speed"
    else
        echo "999 0"
    fi
}

# Setup policy routing tables
setup_routing() {
    log "Setting up policy routing tables..."
    
    # Add custom routing tables
    echo "$WIFI_TABLE    wifi" >> /etc/iproute2/rt_tables 2>/dev/null || true
    echo "$PPP_TABLE     ppp" >> /etc/iproute2/rt_tables 2>/dev/null || true
    
    # Flush old routes
    ip route flush table $WIFI_TABLE 2>/dev/null || true
    ip route flush table $PPP_TABLE 2>/dev/null || true
    
    # Get gateways
    local wifi_gw ppp_gw
    wifi_gw=$(ip route | grep "default.*$WIFI_IF" | awk '{print $3}' | head -1)
    ppp_gw=$(ip route | grep "default.*$PPP_IF" | awk '{print $3}' | head -1)
    
    # Setup WiFi routing table
    if [ -n "$wifi_gw" ]; then
        ip route add default via "$wifi_gw" dev "$WIFI_IF" table $WIFI_TABLE
        ip route add "$wifi_gw" dev "$WIFI_IF" scope link table $WIFI_TABLE
    fi
    
    # Setup PPP routing table  
    if [ -n "$ppp_gw" ]; then
        ip route add default dev "$PPP_IF" table $PPP_TABLE
    else
        # PPP is point-to-point, no gateway needed
        ip route add default dev "$PPP_IF" table $PPP_TABLE
    fi
    
    log "Routing tables configured"
}

# Setup iptables marks for load balancing
setup_iptables() {
    log "Setting up iptables marks for load balancing..."
    
    # Create MARK chain if not exists
    iptables -t mangle -N WAN_LB 2>/dev/null || iptables -t mangle -F WAN_LB
    
    # Add to POSTROUTING
    iptables -t mangle -A POSTROUTING -j WAN_LB 2>/dev/null || true
    
    # Round-robin marking (50/50 split)
    # Using statistic module for packet distribution
    iptables -t mangle -A WAN_LB -m statistic --mode nth --every 2 --packet 0 \
        -j MARK --set-mark $WIFI_MARK
    iptables -t mangle -A WAN_LB -m statistic --mode nth --every 1 --packet 0 \
        -j MARK --set-mark $PPP_MARK
    
    log "iptables marks configured"
}

# Setup routing rules
setup_rules() {
    log "Setting up routing rules..."
    
    # Remove old rules
    ip rule del fwmark $WIFI_MARK table $WIFI_TABLE 2>/dev/null || true
    ip rule del fwmark $PPP_MARK table $PPP_TABLE 2>/dev/null || true
    
    # Add new rules
    ip rule add fwmark $WIFI_MARK table $WIFI_TABLE priority 100
    ip rule add fwmark $PPP_MARK table $PPP_TABLE priority 101
    
    # Enable reverse path filtering relaxation
    sysctl -w net.ipv4.conf.all.rp_filter=2 >/dev/null 2>&1 || true
    sysctl -w net.ipv4.conf.$WIFI_IF.rp_filter=2 >/dev/null 2>&1 || true
    sysctl -w net.ipv4.conf.$PPP_IF.rp_filter=2 >/dev/null 2>&1 || true
    
    log "Routing rules configured"
}

# Enable MPTCP for supported connections
enable_mptcp() {
    log "Enabling MPTCP..."
    
    # Ensure MPTCP is enabled
    sysctl -w net.mptcp.enabled=1
    
    # Use mptcpize to wrap services if needed
    # This makes existing TCP apps use MPTCP automatically
    
    log "MPTCP enabled"
}

# Monitor and adjust based on speed
monitor_speeds() {
    log "Starting speed monitor (interval: ${MONITOR_INTERVAL}s)..."
    
    while true; do
        read wifi_up ppp_up <<< $(check_interfaces)
        
        if [ "$wifi_up" -eq 1 ] && [ "$ppp_up" -eq 1 ]; then
            # Both up - measure and potentially adjust weights
            read wifi_lat wifi_bw <<< $(measure_speed "$WIFI_IF")
            read ppp_lat ppp_bw <<< $(measure_speed "$PPP_IF")
            
            log "WiFi: ${wifi_lat}ms, $(echo "scale=2; $wifi_bw/1024/1024" | bc)MB/s | PPP: ${ppp_lat}ms, $(echo "scale=2; $ppp_bw/1024/1024" | bc)MB/s"
            
            # TODO: Dynamic weight adjustment based on speeds
            # For now, keep 50/50 split
            
        elif [ "$wifi_up" -eq 1 ]; then
            log "WiFi only - routing all traffic via WiFi"
            # Remove PPP marks, route everything via WiFi
            iptables -t mangle -F WAN_LB 2>/dev/null || true
            iptables -t mangle -A WAN_LB -j MARK --set-mark $WIFI_MARK
            
        elif [ "$ppp_up" -eq 1 ]; then
            log "PPP only - routing all traffic via PPP"
            # Remove WiFi marks, route everything via PPP
            iptables -t mangle -F WAN_LB 2>/dev/null || true
            iptables -t mangle -A WAN_LB -j MARK --set-mark $PPP_MARK
            
        else
            log "WARNING: No interfaces up!"
        fi
        
        sleep $MONITOR_INTERVAL
    done
}

# Cleanup on exit
cleanup() {
    log "Cleaning up..."
    
    # Remove iptables rules
    iptables -t mangle -F WAN_LB 2>/dev/null || true
    iptables -t mangle -D POSTROUTING -j WAN_LB 2>/dev/null || true
    
    # Remove routing rules
    ip rule del fwmark $WIFI_MARK table $WIFI_TABLE 2>/dev/null || true
    ip rule del fwmark $PPP_MARK table $PPP_TABLE 2>/dev/null || true
    
    # Flush tables
    ip route flush table $WIFI_TABLE 2>/dev/null || true
    ip route flush table $PPP_TABLE 2>/dev/null || true
    
    log "Cleanup complete"
}

trap cleanup EXIT

# Main
main() {
    log "=========================================="
    log "Multi-WAN Load Balancer Starting..."
    log "=========================================="
    
    # Check root
    [ "$EUID" -ne 0 ] && { log "Must run as root"; exit 1; }
    
    # Setup
    setup_routing
    setup_iptables
    setup_rules
    enable_mptcp
    
    log "Load balancer active!"
    log "Traffic will be distributed across $WIFI_IF and $PPP_IF"
    
    # Start monitoring
    monitor_speeds
}

main "$@"
