# Proxmox VE Baseline Network Architecture & Setup

This guide documents the step-by-step creation of isolated, scalable private NAT networks with automatic DHCP IP allocation on Proxmox VE.

![Proxmox Baseline Network Architecture](docs/architecture/baseline-network.png)

---

### Step 1: Configure Network Interfaces & Private NAT Bridges

Edit your primary network configuration file on the Proxmox host:

```bash
nano /etc/network/interfaces

# Add the following lines to create private NAT bridges for your resources

auto lo
iface lo inet loopback

iface nic1 inet manual
iface nic0 inet manual
iface nic2 inet manual

#--------------------------------------#
# USB Tethering (Commented for reference)
#--------------------------------------#
#auto vmbr0
#iface vmbr0 inet dhcp
#        bridge-ports nic2
#        bridge-stp off
#        bridge-fd 0

#--------------------------------------#
# Primary Wi-Fi Interface (Host Uplink)
# Main Network - 192.168.1.x/24
#--------------------------------------#
auto wlp0s20f3
iface wlp0s20f3 inet static
        address 192.168.1.x/24
        gateway 192.168.1.1
        wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

#--------------------------------------#
# Linux Bridge 1 - Core/Infra (10.10.0.1/24)
# Internal NAT Bridge
#--------------------------------------#
auto vmbr1
iface vmbr1 inet static
        address 10.10.0.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

        # Enable IPv4 Forwarding & Outbound NAT via Wi-Fi Interface
        post-up echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up iptables -t nat -A POSTROUTING -s '10.10.0.0/24' -o wlp0sxxxx -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '10.10.0.0/24' -o wlp0sxxxx -j MASQUERADE

        # Fix Proxmox Firewall / Connection Tracking issue on virtual bridges (Optional)
        post-up   iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
        post-down iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1

#--------------------------------------#
# Linux Bridge 2 - Workload/Platform (10.20.0.1/24)
# Future Expansion (Uncomment when needed)
#--------------------------------------#
#auto vmbr2
#iface vmbr2 inet static
#        address 10.20.0.1/24
#        bridge-ports none
#        bridge-stp off
#        bridge-fd 0

#        post-up iptables -t nat -A POSTROUTING -s '10.20.0.0/24' -o wlp0s20f3 -j MASQUERADE
#        post-down iptables -t nat -D POSTROUTING -s '10.20.0.0/24' -o wlp0s20f3 -j MASQUERADE

source /etc/network/interfaces.d/*

# Restart Network
systemctl restart networking

```

### Step 2: Install & Configure DHCP (dnsmasq)

Install dnsmasq so that VMs attached to vmbr1 (or future bridges) automatically receive IP addresses, routing, and DNS servers.

```bash
# Package Installation
apt update && apt install -y dnsmasq

# Configure dnsmasq
# Backup the default configuration file and open a new one:
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
nano /etc/dnsmasq.conf

# Paste the following environment rules:
# Bind strictly to designated interfaces to prevent host port conflicts
bind-interfaces

# --- LAB NETWORK 1 (Core/Infra) ---
interface=vmbr1
dhcp-range=set:net1,10.10.0.50,10.10.0.200,255.255.255.0,12h
dhcp-option=tag:net1,option:router,10.10.0.1
dhcp-option=tag:net1,option:dns-server,1.1.1.1,8.8.8.8

# --- LAB NETWORK 2 (Workload/Platform - Optional Future Expansion) ---
# interface=vmbr2
# dhcp-range=set:net2,10.20.0.50,10.20.0.200,255.255.255.0,12h
# dhcp-option=tag:net2,option:router,10.20.0.1
# dhcp-option=tag:net2,option:dns-server,1.1.1.1,8.8.8.8

# Enable & Restart Service
systemctl restart dnsmasq
systemctl enable dnsmasq

# Note: Execute systemctl restart dnsmasq whenever updates are made to /etc/dnsmasq.conf.
```

### Step 3: Verification & Testing

Verify Interface Status:

```bash
ip a show vmbr1
# Ensure vmbr1 is active with IP 10.10.0.1/24.
```

Verify DHCP Service:

```bash
systemctl status dnsmasq
# Ensure the service shows active (running) without interface binding errors.
```
