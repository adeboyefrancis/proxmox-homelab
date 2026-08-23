#!/bin/bash
# Seals the template before Packer converts it -- every step here exists
# because of a real bug hit during manual VM builds: unsealed templates
# cause every clone to share host keys/machine-id, which breaks cloud-init's
# first-boot detection and triggers SSH "host key changed" warnings on
# every reboot.

set -euo pipefail

echo "Sealing template..."

# --- Security: remove the Packer build-time backdoor ---
# The 'ubuntu' user with a password existed only so Packer's SSH
# communicator could connect during the build. Without this step, every
# VM cloned from this template would carry a live, password-authenticated
# account forever -- alongside your intended per-VM Terraform-managed user.
passwd -l ubuntu
rm -f /etc/sudoers.d/ubuntu-build

# --- SSH host keys: regenerated fresh on each clone's first boot ---
rm -f /etc/ssh/ssh_host_*

# --- cloud-init state: forces correct first-boot detection per clone ---
cloud-init clean --logs --machine-id

# --- machine-id: systemd assigns a unique one on next boot ---
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# --- Package cache and logs ---
apt-get autoremove -y
apt-get autoclean
rm -rf /var/lib/apt/lists/*

for user_home in /root /home/*; do
  truncate -s 0 "$user_home/.bash_history" 2>/dev/null || true
done

journalctl --rotate
journalctl --vacuum-time=1s
truncate -s 0 /var/log/syslog 2>/dev/null || true
truncate -s 0 /var/log/auth.log 2>/dev/null || true

rm -rf /tmp/* /var/tmp/*

echo "Sealing complete."