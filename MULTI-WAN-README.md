# Multi-WAN Load Balancer for Laptop

Combine WiFi + Cellular (PPP) connections for **increased throughput** and **better reliability**.

## Your Setup

```
┌─────────────────┐
│   Your Laptop   │
│                 │
│  wlp0s20f3      │  WiFi (TP-LINK)      → 192.168.0.109  → Broadband
│  ppp0           │  T-Mobile USB Modem  → 10.226.20.63   → Cellular
└─────────────────┘
```

## Why NOT Standard Bonding?

Network bonding (802.3ad, balance-rr, etc.) **won't work** for your case because:
- Bonding requires interfaces to reach the **same network/gateway**
- Your WiFi and PPP connect to **different networks** with **different public IPs**
- They're different Layer 2 technologies

## Solution: Policy-Based Load Balancing + MPTCP

### What You Get

| Feature | How It Works |
|---------|--------------|
| **Per-connection LB** | New connections alternate between WiFi/PPP |
| **MPTCP support** | Apps using MPTCP get true aggregation |
| **Auto-failover** | If one drops, traffic goes to the other |
| **Speed monitoring** | Logs show real-time performance |

---

## Quick Start

### 1. Install Dependencies

```bash
sudo apt-get install -y mptcpd mptcpize iptables
```

### 2. Start Load Balancer

```bash
cd /home/rgr/W/cloudforge/homelab
sudo ./multi-wan-simple.sh
```

### 3. Test It

Open multiple downloads/streams and watch them distribute:

```bash
# Monitor connections
watch -n1 'ss -tm | grep -E "(WiFi|ppp|wlp)"'

# Check MPTCP usage
ip mptcp endpoint show

# Monitor throughput
iftop -mB
```

---

## How It Works

```
New Connection → Mark (50/50 split) → Route via marked interface
                      │
              ┌───────┴───────┐
              │               │
         Mark 0x100      Mark 0x101
         (WiFi)          (PPP)
              │               │
         Table 100       Table 101
              │               │
         wlp0s20f3        ppp0
```

### Connection Flow

1. **New TCP connection** starts (e.g., browser request)
2. **iptables marks** it (alternating WiFi/PPP)
3. **Policy routing** sends it via marked interface's table
4. **Return traffic** follows same path (conntrack)

---

## MPTCP Support

Your kernel has MPTCP enabled (`net.mptcp.enabled = 1`).

### Check MPTCP Status

```bash
# Show MPTCP endpoints
ip mptcp endpoint show

# Show MPTCP connections (will show "mpcapable" if using MPTCP)
ss -tm | grep -i mpcp
```

### Use MPTCP with Apps

For apps that don't natively support MPTCP, use `mptcpize`:

```bash
# Run a single command with MPTCP
mptcpize run curl https://example.com

# Make a service always use MPTCP
mptcpize enable firefox
```

---

## Monitoring

### Check Distribution

```bash
# Count connections per interface
ss -to state established | grep -c "wlp0s20f3"
ss -to state established | grep -c "ppp0"
```

### Speed Test Each Path

```bash
# Via WiFi
curl -o /dev/null --interface wlp0s20f3 https://speed.cloudflare.com/__down?bytes=10000000

# Via PPP
curl -o /dev/null --interface ppp0 https://speed.cloudflare.com/__down?bytes=10000000
```

### Real-time Monitoring

```bash
# Watch connection marks
watch -n1 'iptables -t mangle -L WAN_LB -v -n'

# Watch routing tables
watch -n1 'ip route show table 100; echo "---"; ip route show table 101'
```

---

## Systemd Service (Auto-start)

```bash
# Copy service file
sudo cp multi-wan-lb.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable multi-wan-lb
sudo systemctl start multi-wan-lb

# Check status
systemctl status multi-wan-lb
```

---

## Limitations

### What This DOESN'T Do

❌ **Single connection won't be faster**
   - Each TCP connection uses only ONE interface
   - Multiple connections get distributed

❌ **MPTCP needs server support**
   - Most websites don't support MPTCP yet
   - Works great for your own MPTCP-enabled servers

### What This DOES Do

✅ **Multiple parallel connections = faster overall**
   - Downloading multiple files? They split across interfaces
   - Multiple browser tabs? Distributed automatically

✅ **Better reliability**
   - If WiFi drops, PPP takes over
   - No manual intervention needed

---

## Advanced: Dynamic Speed-Based Routing

For true **speed-aware routing** (send traffic via faster interface), you'd need:

1. **Continuous speed monitoring** (latency + bandwidth)
2. **Dynamic weight adjustment** (not 50/50, but 70/30 based on speed)
3. **BGP or SD-WAN** for production use

Tools for this:
- **VyOS** - Full router OS with WAN LB
- **pfSense/OPNsense** - Multi-WAN load balancer
- **OpenMPTCProuter** - MPTCP-based aggregation (needs server)

---

## Troubleshooting

### No Internet After Starting

```bash
# Check routing
ip route show
ip route show table 100
ip route show table 101

# Check marks
iptables -t mangle -L WAN_LB -v -n

# Test direct connectivity
ping -I wlp0s20f3 8.8.8.8
ping -I ppp0 8.8.8.8
```

### One Interface Not Working

```bash
# Check interface status
ip -br link show

# Check IP addresses
ip addr show wlp0s20f3
ip addr show ppp0

# Restart NetworkManager connections
nmcli connection down "TP-LINK_5393"
nmcli connection up "TP-LINK_5393"
```

### MPTCP Not Working

```bash
# Verify kernel support
sysctl net.mptcp.enabled

# Check mptcpd is running
systemctl status mptcp

# View MPTCP endpoints
ip mptcp endpoint show
```

---

## Performance Expectations

| Scenario | Expected Gain |
|----------|---------------|
| Single download | No gain (uses one interface) |
| Multiple parallel downloads | ~2x aggregate speed |
| MPTCP-enabled server | Up to 2x per-connection |
| WiFi down, PPP backup | 100% reliability |

### Your Current Speeds

```
WiFi (TP-LINK):   ~9 Mbps download
PPP (T-Mobile):   Test needed (cellular varies)
-----------------------------------------
Combined:         Up to ~18 Mbps aggregate
```

---

## Alternative: OpenMPTCProuter

For **true bandwidth aggregation** (single connection uses both):

1. **Rent a VPS** (€5/month, needs public IP)
2. **Install OpenMPTCProuter** on VPS + laptop
3. **All traffic** goes through VPS via MPTCP
4. **True aggregation** - single connection uses both links

Pros:
- Single TCP connection uses both interfaces
- Works with any website/app
- Encryption + compression optional

Cons:
- Needs external server
- Adds latency (traffic routes via VPS)
- More complex setup

See: https://www.openmptcprouter.com/

---

## License

MIT - Use at your own risk. Test before relying on it.
