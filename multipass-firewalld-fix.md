# Multipass Firewalld Configuration Fix for Fedora

**Date:** 2025-11-17  
**System:** Fedora Linux with firewalld and Docker  
**Issue:** Multipass VM launch timeouts due to firewall blocking

## Root Cause

Multipass on Fedora with firewalld active was experiencing timeout issues because:

1. The Multipass bridge interface `mpqemubr0` was not assigned to any firewalld zone
2. Masquerading (NAT) was not enabled for the Multipass network
3. FORWARD chain rules were blocking traffic due to Docker's iptables rules

## Solution Applied (Persistent Configuration)

The following firewalld configuration changes were made with the `--permanent` flag to ensure they survive reboots:

### 1. Add mpqemubr0 to the trusted zone
```bash
sudo firewall-cmd --permanent --zone=trusted --add-interface=mpqemubr0
```

### 2. Enable masquerading for NAT
```bash
sudo firewall-cmd --permanent --zone=trusted --add-masquerade
```

### 3. Add direct FORWARD rules for mpqemubr0
```bash
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i mpqemubr0 -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -o mpqemubr0 -j ACCEPT
```

### 4. Reload firewalld to apply changes
```bash
sudo firewall-cmd --reload
```

## Configuration Verification

To verify the configuration is active and persistent:

```bash
# Check active zones (should show mpqemubr0 under trusted)
sudo firewall-cmd --get-active-zones

# Check permanent trusted zone config
sudo firewall-cmd --permanent --zone=trusted --list-all

# Check direct rules
sudo firewall-cmd --permanent --direct --get-all-rules

# Verify masquerading is enabled
sudo firewall-cmd --zone=trusted --query-masquerade
```

Expected output for trusted zone:
```
trusted
  target: ACCEPT
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: mpqemubr0
  sources: 
  services: 
  ports: 
  protocols: 
  forward: yes
  masquerade: yes
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```

Expected direct rules:
```
ipv4 filter FORWARD 0 -i mpqemubr0 -j ACCEPT
ipv4 filter FORWARD 0 -o mpqemubr0 -j ACCEPT
```

## System Information

- **Multipass Version:** 1.16.1
- **Virtualization Driver:** qemu
- **SELinux Mode:** Enforcing
- **Firewalld:** Active
- **Other virtualisation:** Docker, libvirt (virbr0)

## Testing

After applying the fix, VMs launch successfully:

```bash
# Launch test VM
multipass launch --verbose --timeout 300 24.04 --name nas-test --memory 4G --disk 20G

# Verify running state and IP
multipass list
multipass info nas-test

# Test connectivity
multipass exec nas-test -- ping -c 3 8.8.8.8
multipass exec nas-test -- ping -c 3 archive.ubuntu.com
```

## Reboot Persistence

All configuration changes use the `--permanent` flag and are stored in firewalld's permanent configuration at:
- `/etc/firewalld/zones/trusted.xml` (zone configuration)
- `/etc/firewalld/direct.xml` (direct rules)

After a system reboot:
1. Firewalld automatically loads the permanent configuration
2. Multipass daemon starts and creates the mpqemubr0 bridge
3. The bridge is automatically assigned to the trusted zone
4. VMs can launch and access the network without issues

## Alternative: Custom Zone (Not Used)

If you prefer not to use the trusted zone, you can create a dedicated zone:

```bash
sudo firewall-cmd --permanent --new-zone=multipass
sudo firewall-cmd --permanent --zone=multipass --add-interface=mpqemubr0
sudo firewall-cmd --permanent --zone=multipass --set-target=ACCEPT
sudo firewall-cmd --permanent --zone=multipass --add-masquerade
sudo firewall-cmd --reload
```

## Troubleshooting Commands

If issues occur after reboot or updates:

```bash
# Check if Multipass daemon is running
systemctl status snap.multipass.multipassd.service

# Check if bridge exists
ip link show mpqemubr0

# Verify firewalld zones
sudo firewall-cmd --get-active-zones

# Check iptables NAT rules
sudo iptables -t nat -L -n -v

# Check IP forwarding is enabled
sysctl net.ipv4.ip_forward

# View Multipass logs
journalctl -u snap.multipass.multipassd.service -n 100

# Restart Multipass if needed
sudo systemctl restart snap.multipass.multipassd.service
```

## Summary

This configuration allows Multipass VMs on Fedora to:
- ✅ Launch without timeout errors
- ✅ Obtain IP addresses via DHCP
- ✅ Access external networks and the internet
- ✅ Work alongside Docker and libvirt
- ✅ Survive system reboots
- ✅ Maintain security with SELinux in Enforcing mode

---
*Last verified: 2025-11-17*
