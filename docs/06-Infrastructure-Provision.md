# 06 — Core Infrastructure Provisioning

**Stack:** Terraform (provisioning) + Packer (golden image) + a persistent Host-to-lab network path, in that dependency order.

This doc consolidates three pieces that must happen in sequence — doing them out of order means solving the same routing problem three separate times, as this project did the first time through.

---

## A. Mac Workstation — Persistent Lab Network Access

**Do this first.** Everything below (Terraform's snippet uploads, Packer's build-VM access) gets simpler once your Mac can already reach both lab subnets directly.

**Goal:** your Host machine (Mac) reaches `10.10.0.0/24` and `10.20.0.0/24` directly, on every boot, with no manual `route add` and no jump host.

**Files:** `automation/mac/static-routes.sh`, `automation/mac/com.devlab.static-routes.plist`

```bash
#!/bin/bash
# automation/mac/static-routes.sh
# Adds persistent routes to both lab subnets via the Proxmox host, so the
# Mac can reach every VM/LXC directly without a jump host or per-session
# `route add`. Run automatically at boot by the LaunchDaemon below.

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

/sbin/route -n add -net 10.10.0.0/24 "$PROXMOX_GATEWAY" >> "$LOG_FILE" 2>&1
/sbin/route -n add -net 10.20.0.0/24 "$PROXMOX_GATEWAY" >> "$LOG_FILE" 2>&1

echo "$(date): Done." >> "$LOG_FILE"
```

```xml
<!-- automation/mac/com.devlab.static-routes.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.devlab.static-routes</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/usr/local/bin/devlab-static-routes.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/devlab-routes.out.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/devlab-routes.err.log</string>
</dict>
</plist>
```

### A.1 Install

- [ ] Place the script:
  ```bash
  sudo cp automation/mac/static-routes.sh /usr/local/bin/devlab-static-routes.sh
  sudo chmod +x /usr/local/bin/devlab-static-routes.sh
  ```
- [ ] Install the LaunchDaemon (must be root-owned or macOS silently refuses to load it):
  ```bash
  sudo cp automation/mac/com.devlab.static-routes.plist /Library/LaunchDaemons/
  sudo chown root:wheel /Library/LaunchDaemons/com.devlab.static-routes.plist
  sudo chmod 644 /Library/LaunchDaemons/com.devlab.static-routes.plist
  ```
- [ ] Load it immediately, rather than waiting for next reboot:
  ```bash
  sudo launchctl load /Library/LaunchDaemons/com.devlab.static-routes.plist
  ```

### A.2 Verify

```bash
netstat -rn | grep 10.10.0.0
netstat -rn | grep 10.20.0.0
ssh 10.10.0.10   # direct, no jump host, no -i/-J flags
```

### A.3 Troubleshooting

```bash
cat /tmp/devlab-routes.log
cat /tmp/devlab-routes.err.log

# If WiFi took longer than ~30s to associate at boot, re-run manually:
sudo /usr/local/bin/devlab-static-routes.sh
```

### A.4 Uninstalling

```bash
sudo launchctl unload /Library/LaunchDaemons/com.devlab.static-routes.plist
sudo rm /Library/LaunchDaemons/com.devlab.static-routes.plist
sudo rm /usr/local/bin/devlab-static-routes.sh
```

---

## B. Terraform — Proxmox Provider & Provisioning

**Goal:** provision every VM and LXC declaratively, running from the Mac, with remote state in HCP Cloud.

### B.1 Install

- [ ] `brew tap hashicorp/tap && brew install hashicorp/tap/terraform`
- [ ] `terraform -v`

### B.2 Connect to HCP Cloud for State

- [ ] Create an HCP Terraform organization + workspace for this project
- [ ] Point the `cloud` block at that workspace
- [ ] `terraform login`

### B.3 Provider Setup

`infrastructure/providers.tf`:

```hcl
terraform {
  cloud {
    organization = "your-org"
    workspaces { name = "proxmox-homelab" }
  }
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

provider "proxmox" {
  # Use the domain if you set up the Route53/ACME cert (Phase 1) --
  # a cert issued for a domain won't validate against a bare IP.
  endpoint  = "https://devlab.yourdomain.tld:8006"
  insecure  = false

  # Alternative if you haven't set up a cert yet: bare IP, skip validation
  # endpoint  = "https://192.168.1.150:8006"
  # insecure  = true

  api_token = var.proxmox_api_token

  # Needed specifically for cloud-init snippet uploads -- the API can't
  # write host filesystem files, so the provider SSHes into Proxmox
  # directly for that one operation.
  ssh {
    agent       = false
    private_key = file("~/.ssh/id_ed25519_proxmox")
    username    = "root"
  }
}
```

- [ ] Store `proxmox_api_token` as a sensitive variable in HCP Terraform, not the repo
- [ ] Set `var.ssh_public_key` to the contents of `~/.ssh/id_ed25519_proxmox.pub` — injected into every VM's `user_account.keys`
- [ ] `terraform init`

### B.4 The Golden Image

> The template Terraform clones from is built by **Packer, not Terraform** — see Section C below. Terraform's only job here is `clone { vm_id = var.vm_template_id }`. Don't maintain a second, separate bootstrap path for the template; one source of truth avoids drift.

### B.5 Node Resources

- [ ] `infrastructure/vmbr1.tf` — automation VM, dns/vault/runner LXCs (all cloned from the Packer golden image)
- [ ] `infrastructure/vmbr2.tf` — docker-host, k3s-01, k3s-02 VMs
- [ ] Each resource sets: CPU, memory, disk size, network bridge, static IP via cloud-init

**Minimal VM example** (see `automation/automation-vm.tf` for a complete real one, including the cloud-init snippet pattern):

```hcl
resource "proxmox_virtual_environment_vm" "automation" {
  name      = "automation"
  node_name = var.node_name

  clone {
    vm_id = var.vm_template_id
  }

  cpu    { cores = 2 }
  memory { dedicated = 2048 }

  network_device {
    bridge = "vmbr1"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.10.0.10/24"
        gateway = "10.10.0.1"
      }
    }
  }
}
```

**Minimal LXC example:**

```hcl
resource "proxmox_virtual_environment_container" "dns" {
  node_name = var.node_name
  vm_id     = 201

  network_interface {
    bridge = "vmbr1"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.10.0.20/24"
        gateway = "10.10.0.1"
      }
    }
  }
}
```

> **Provisioning tip:** LXCs only support a `root` login (no equivalent to a VM's named `user_account`), and Ansible's control node authenticates as a distinct user. Add **both** your Mac's key and the automation VM's own key to every LXC's `user_account.keys` at creation time — retrofitting this after the fact means manually appending keys via `qm guest exec` later.

### B.6 Provision

```bash
terraform plan    # review before applying
terraform apply
```

Confirm nodes exist and are reachable — with Section A's routes and the Phase 1.9 SSH config, this works directly:

```bash
ssh 10.10.0.10
```

**If a node is unreachable after apply**, diagnose via the Proxmox guest agent rather than guessing — it bypasses SSH entirely, so it can't be affected by whatever's blocking SSH:

```bash
ssh proxmox-node
qm guest exec <vmid> -- cat /home/<user>/.ssh/authorized_keys
qm guest exec <vmid> -- cloud-init status --long
```

If the fix requires recreating the node:

```bash
terraform destroy -target=<resource.address>
ssh-keygen -R <node-ip>   # clear the stale host key -- a recreated node has a new one
terraform apply
```

---

## C. Packer — Golden Image Build

**Goal:** one reusable, sealed Ubuntu image that Terraform clones for every VM.

### C.1 Install

- [ ] `brew tap hashicorp/tap && brew install hashicorp/tap/packer`
- [ ] `packer -v`

### C.2 Network Access for the Build

With Section A already in place, **no action needed** — Packer builds a VM directly on Proxmox, which gets a DHCP address on `vmbr1`; your Mac already routes there persistently.

- [ ] Quick confirmation it's active:
  ```bash
  netstat -rn | grep 10.10.0.0
  ```

**Alternative, if you'd rather not modify your Mac's routing table at all:** Packer supports its own bastion tunnel natively, independent of Section A:

```hcl
ssh_bastion_host     = "devlab.yourdomain.tld"
ssh_bastion_port     = 22
ssh_bastion_username = "root"
ssh_bastion_password = var.proxmox_ssh_password  # parameterize, never hardcode
```

This is a genuine alternative, not a fallback for a broken setup — pick whichever you prefer. If Section A's routes are already working, you don't need both.

### C.3 Prerequisite: Upload the ISO

- [ ] Proxmox UI → your node → local (storage) → ISO Images → Upload → Ubuntu Server 22.04 ISO
- [ ] Confirm the exact filename matches what the template expects:
  ```bash
  ls /var/lib/vz/template/iso/
  ```

### C.4 Template Structure

```
automation/packer/
├── ubuntu-golden.pkr.hcl   # proxmox-iso builder + build steps
├── secrets.pkrvars.hcl     # Variables
├── http/
│   ├── user-data           # autoinstall config, served over HTTP by Packer
│   └── meta-data           # empty, required alongside user-data
└── scripts/
    └── cleanup.sh          # sealing steps, runs last
```

- [ ] Uses the **`proxmox-iso`** builder — not the generic `qemu` builder, which runs locally with no KVM acceleration and produces a `.qcow2` file, not a Proxmox template
- [ ] Points at `node_name = var.node_name`, `vmbr1`, `template_vm_id = 9000`
- [ ] `user-data` sets a temporary build-only password for a `ubuntu` user — locked in `cleanup.sh`, never left active

### C.5 What to Bake In

Universal packages only. Role-specific tools (Ansible, Docker, k3s) stay out of the base image and get installed per-VM later, so this one template works for automation, docker-host, _and_ k3s nodes without bloating any of them:

```
qemu-guest-agent openssh-server curl wget git vim python3 python3-pip ca-certificates gnupg lsb-release jq htop
```

### C.6 Sealing Steps (Critical)

> **Why this matters:** without this, every clone inherits the same machine-id and SSH host keys as the template and every other clone — the root cause of the recurring "REMOTE HOST IDENTIFICATION HAS CHANGED" warning and cloud-init misdetecting first boots.

`scripts/cleanup.sh`, run as the final provisioner:

- [ ] **Lock the build user** — `passwd -l ubuntu` + remove its sudoers file. Without this, every clone carries a live password-authenticated backdoor.
- [ ] **Remove SSH host keys** — `rm -f /etc/ssh/ssh_host_*`
- [ ] **Clear cloud-init state** — `cloud-init clean --logs --machine-id`
- [ ] **Clear machine-id** — truncate, remove and relink `/var/lib/dbus/machine-id`
- [ ] **Clean package cache, bash history, logs**

### C.7 Build

```bash
cd automation/packer
packer init .
packer fmt .
packer validate -var-file="secrets.pkrvars.hcl" .
packer build -var-file="secrets.pkrvars.hcl" .        # expect 20-40 minutes
```

- [ ] Confirm the template appears in Proxmox as `vm_id 9000`, marked as a template

### C.8 Cleaning Up Old Builds

```bash
rm -f manifest.json
rm -rf packer_cache/
rm -f crash.log
```

### Deliverables

- A golden Ubuntu template in Proxmox, ready for Terraform to clone
- Universal packages pre-installed (git, python3, jq, etc.) — Ansible and Docker are deliberately **not** included; those install per-VM in later phases
- Properly sealed: unique machine-id, SSH host keys, and cloud-init instance-ID per clone
- A repeatable process for updating the base image (`packer build` again when you want a patched base)
