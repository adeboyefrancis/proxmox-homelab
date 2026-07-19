# Proxmox VE Post-Install & Wireless Setup Guide (Steps 6-8)

This covers the second phase of the setup: transitioning Proxmox host from the temporary mobile bootstrap network to a stable, permanent Wi-Fi network using a temporary DHCP handshake before locking down a dedicated static IP address.

---

## Step 6: Configure Repositories & Temporary Wireless DHCP Link

Because Proxmox omits wireless utilities by default, we must use our working phone connection to download packages. However, to pass that connection smoothly over to the wireless card configuration, we temporarily initialize the Wi-Fi card interface as a DHCP client.

1. **Disable Enterprise Repositories:** Comment out the enterprise repository to prevent update errors:

   ```bash
   sed -i 's/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
   ```

2. **Add No-Subscription Repositories:** Append the community mirror to fetch public updates:

   ```bash
   echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list
   ```

3. **Identify the Wireless Interface Name:** Find the hardware identification string assigned to your built-in Wi-Fi card:

   ```bash
   ip a
   ```

   Look for the entry showing `altname wlan0` (Commonly `wlp0s***` or similar on Intel 10th Gen architectures). Note this exact value down.

4. **Configure Temporary DHCP for Wi-Fi:** Open the main system network configuration file:

   ```bash
   nano /etc/network/interfaces
   ```

   Set up your Wi-Fi interface using **dhcp** temporarily so it can communicate through your network router to fetch dependencies. Paste or adjust the configuration to match this pattern (replacing `wlp0s***` with your card name):

   ```plaintext
   auto lo
   iface lo inet loopback

   iface nic0 inet manual

   # Temporary DHCP Wi-Fi Setup for package download
   auto wlp0s***
   iface wlp0s*** inet dhcp
           wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
   ```

5. **Generate Wi-Fi Connection Credentials:** Build your security profile so the card can log into your home router:

   ```bash
   mkdir -p /etc/wpa_supplicant
   wpa_passphrase "YOUR_WIFI_NAME" "YOUR_WIFI_PASSWORD" > /etc/wpa_supplicant/wpa_supplicant.conf
   ```

6. **Fetch Wireless Engines & System Monitors:** Restart your networking engine to authenticate to your home router via DHCP. Once a wireless lease is obtained, download the essential software tools:
   ```bash
   systemctl restart networking
   apt update && apt install -y wpasupplicant wireless-tools iptables-persistent htop iftop ncdu btop smartmontools lm-sensors
   ```

---

## Step 7: Transition to Static Network Configuration

Now that the wireless applications are fully installed on your host, you must convert the temporary DHCP interface into your permanent static home lab IP layout.

1. **Lock Down the Static IP:** Reopen your network configurations file:

   ```bash
   nano /etc/network/interfaces
   ```

2. **Apply Final Production Ruleset:** Wipe out the temporary DHCP block and map out your dedicated home network scope alongside an isolated virtual bridge framework (`vmbr0`) for internal virtual machine use:

   ```plaintext
   auto lo
   iface lo inet loopback

   iface nic0 inet manual

   # 1. Physical Wi-Fi Interface Configuration (Permanent Static Host Access)
   auto wlp0s***
   iface wlp0s*** inet static
           address 192.168.1.x/24
           gateway 192.168.1.1
           wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

   # 2. Virtual Bridge (Kept isolated for internal VM NAT routing)
   auto vmbr0
   iface vmbr0 inet manual
           bridge-ports none
           bridge-stp off
           bridge-fd 0
   ```

   _Note: Home wireless access points drop multiple virtual MAC addresses over a single wireless link. Keeping `bridge-ports none` ensures the server remains stable, though VMs will require NAT routing configured in a later step._

3. **Apply Changes & Unplug Phone:** Reload the production network stack to lock in the static IP changes:

   ```bash
   systemctl restart networking
   ```

   _(You can now safely disconnect your smartphone from the server's USB port)._

4. **Confirm Stable Connection:** Verify that the system holds your static IP address and routes public traffic properly over the air:
   ```bash
   ip a show dev wlp0s***
   ping -c 4 8.8.8.8
   ```

---

## Step 8: Post-Installation Web GUI Access & Clean Up

1. **Access the Panel:** Move over to your main workstation desktop/laptop connected to the same home Wi-Fi network, open a web browser, and go to:

   ```text
   https://192.168.1.x:8006
   ```

2. **Remove Subscription Nag Box:** Launch a terminal connection via SSH (`ssh root@192.168.1.x`) or use the Web UI shell console, then navigate to the core widget toolkit directory:

   ```bash
   cd /usr/share/javascript/proxmox-widget-toolkit
   ```

3. **Edit Configuration:** Open the library file:

   ```bash
   nano proxmoxlib.js
   ```

   Search for the string `No valid subscription` (`Ctrl + W`) and adjust the verification block to suppress the alert dialogue window.

4. **Restart Proxy Service:** Reload the PVE dashboard proxy configuration to apply the change immediately:
   ```bash
   systemctl restart pveproxy
   ```
