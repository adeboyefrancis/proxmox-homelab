#!/bin/bash
set -e

echo "==> Clearing apt cache and package management leftovers..."
sudo apt-get clean
sudo apt-get autoremove -y

echo "==> Deleting the temporary Packer user SSH keys..."
sudo rm -rf /home/ubuntu/.ssh/authorized_keys

echo "==> Purging the shared SSH Host Keys - clones generate unique keys..."
sudo rm -f /etc/ssh/ssh_host_*

echo "==> Cleaning out Cloud-Init runtime cache and logs - generate unique identifiers..."
sudo cloud-init clean --logs

echo "==> Resetting machine-id so clones generate unique identifiers..."
# Truncating these files to 0 bytes tells Ubuntu to regenerate unique machine IDs on next boot
sudo truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ]; then
    sudo truncate -s 0 /var/lib/dbus/machine-id
fi

echo "==> Clearing shell history tracks..."
history -c
cat /dev/null > ~/.bash_history

echo "==> Image sealing complete!"
