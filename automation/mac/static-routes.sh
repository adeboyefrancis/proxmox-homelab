#!/bin/bash

# Adds persistent routes to both lab subnets via the Proxmox host, so the
# Mac can reach every VM/LXC directly without a jump host or per-session
# `route add`. Run automatically at boot by the LaunchDaemon in this folder.

PROXMOX_GATEWAY="192.168.1.150"
LOG_FILE="/tmp/devlab-routes.log"

echo "$(date): Adding devlab routes via ${PROXMOX_GATEWAY}" >> "$LOG_FILE"

# Retry briefly in case this runs before WiFi is fully up at boot
for i in {1..10}; do
  if ping -c 1 -t 2 "$PROXMOX_GATEWAY" >/dev/null 2>&1; then
    break
  fi
  echo "$(date): Waiting for network (attempt $i)..." >> "$LOG_FILE"
  sleep 3
done

{
  /sbin/route -n add -net 10.10.0.0/24 "$PROXMOX_GATEWAY"
  /sbin/route -n add -net 10.20.0.0/24 "$PROXMOX_GATEWAY"
} >> "$LOG_FILE" 2>&1

echo "$(date): Done." >> "$LOG_FILE"