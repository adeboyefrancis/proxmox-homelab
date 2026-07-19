## Installation of Proxmox on Mini PC (HP Elite Prodesk 400 G6 10th Gen)

### Prerequisites

- **Server Hardware:** HP ProDesk 400 G6 Mini PC (Intel 10th Gen, 32GB RAM, 512GB SSD).
- **Local Workstation:** A separate laptop or desktop to download files and flash the USB.
- **Installation Media:** USB drive (4GB or larger).
- **Peripherals:** Wired USB keyboard and a monitor physically connected to the Mini PC.
- **Temporary Network:** A smartphone (Android/iPhone) with a data plan and USB cable for USB tethering (used to bootstrap the internet if an Ethernet drop isn't immediately available).
- **Home Router IP** Typically, **192.168.1.x**

---

### Step 1: Prepare the Installation Media

_Perform these steps on your separate workstation laptop/desktop._

1. **Download Proxmox:** Download the latest Proxmox VE ISO from the official [Proxmox Downloads](https://www.proxmox.com/en/downloads) page.
2. **Setup Ventoy:** Download and install [Ventoy](https://www.ventoy.net/en/download.html), then format your USB drive using the Ventoy application.
3. **Load the ISO:** Copy the downloaded Proxmox ISO file directly onto the Ventoy USB drive partition.

---

### Step 2: Configure BIOS and Boot from USB

_Perform these steps on the HP Mini PC._

1. **Connect Media:** Insert the Ventoy USB drive into a USB port on the Mini PC.
2. **Enter BIOS:** Power on the Mini PC and repeatedly tap **F10** to enter the BIOS/UEFI settings.
3. **Disable Secure Boot:** Navigate to the security/boot configuration settings, locate **Secure Boot**, and set it to **Disabled**.
4. **Boot Menu:** Save changes and exit. As the machine restarts, immediately and repeatedly tap **F9** to open the HP Boot Menu.
5. **Launch Installer:** Select your USB drive from the menu list. Once the Ventoy interface loads, select the Proxmox VE ISO to launch the installer.

---

### Step 3: Establish Bootstrap Network (USB Tethering)

_Crucial: This must be done BEFORE selecting "Install Proxmox VE" from the boot menu so the installer can detect the network interface._

1. **Connect the Device:** Connect your smartphone to one of the Mini PC's USB ports using a high-quality data cable.
2. **Enable Tethering:**
   - **Android:** Go to _Settings > Network & Internet > Hotspot & tethering_ and toggle on **USB tethering**.
   - **iPhone:** Go to _Settings > Personal Hotspot_ and toggle on **Allow Others to Join**.
3. **Verify Connection:** Ensure the phone shows it is actively sharing its data connection.
4. **Boot the Installer:** Now, select **Install Proxmox VE (Graphical)** from the Ventoy menu. The Proxmox installer will load and automatically detect the phone as a USB network interface (typically named something like `enp0s20u...` or `eth0`).

---

### Step 4: Proxmox Installer GUI Configuration

1. **EULA & Target Hard Drive:** Accept the license agreement. Select your **512GB SSD** as the target hard drive.
2. **Location & Time Zone:** Select your Country, Time Zone, and Keyboard Layout.
3. **Credentials:** Set your `root` password and enter your primary email address for system alerts.
4. **Management Network Configuration:**
   - **Management Interface:** Select the USB tethered network interface from the dropdown list (verify it matches the mobile interface detected in Step 3).
   - **Hostname (FQDN):** Enter a local domain name for your server (e.g., `pve01.homelab.local`).
   - **IP Address:** The installer will likely pull a DHCP IP from your phone (e.g., `192.168.1.x` or `172.20.10.x`). **Keep this configuration as-is for now.** You will change this to a permanent static IP later once you connect to your home router.
   - **Gateway & DNS:** Leave these as the auto-detected values pulled from your phone.
5. **Review & Install:** Review your settings and click **Install**. Once finished, the Mini PC will reboot. Unplug the Ventoy USB drive when prompted.
