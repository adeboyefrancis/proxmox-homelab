# Infrastructure as Code (Hashicorp Terraform)

**Goal:** Provision every VM and LXC declaratively running terraform from host machine for a r, with remote state backend managed in HCP Cloud.

## 2.1 Install Terraform

- [ ] `brew tap hashicorp/tap && brew install hashicorp/tap/terraform`
- [ ] `terraform -v`

## 2.2 Connect to HCP Cloud for State

- [ ] Create an HCP Terraform organization + workspace for this project
- [ ] In your `.tf` config, set the `cloud` block to point at that workspace
- [ ] `terraform login` to authenticate your Host machine

## 2.3 Proxmox Provider Setup

- [ ] Place this in `infrastructure/providers.tf`:

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
    endpoint  = "https://192.168.1.x:8006"
    api_token = var.proxmox_api_token
    insecure  = true # Set to fales if SSL Certificate or Public Domain are Present

# Option A: use the domain (matches the cert, insecure = false works)
# endpoint  = "https://domain-nanme:8006"
# insecure  = false

# Option B: keep the IP, accept the cert isn't checked
# endpoint  = "https://192.168.1.x:8006"
# insecure  = true

    # SSH Configuration that allow Cloud-init
    ssh {
      agent       = false
      private_key = file("~/.ssh/id_ed25519_proxmox")
      username    = "root"
    }
  }
```

- [ ] Store `proxmox_api_token` as a sensitive variable in HCP Terraform, not in the repo
- [ ] Set `var.ssh_public_key` to the contents of `~/.ssh/id_ed25519_proxmox.pub` — this is what gets injected into every VM's `user_account.keys`
- [ ] Initialize Terraform workspace by running `terraform init` to establish trust relationship between terraform and proxmox via REST API.

## 2.4 Download Ubuntu ISO Image Manually , CLI , Terraform or Packer

```hcl
# Option 1 - Terraform
# infrastructure/template.tf

resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"  # your node's name
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  file_name    = "jammy-server-cloudimg-amd64.qcow2"
}
```

```bash
# Download the Ubuntu 22.04 cloud image
cd /var/lib/vz/template/iso/
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Install qemu-guest-agent into the image (useful for Proxmox integration)
# This requires libguestfs-tools
apt-get install -y libguestfs-tools
virt-customize -a jammy-server-cloudimg-amd64.img \
  --install qemu-guest-agent \
  --run-command "systemctl enable qemu-guest-agent"

# Create a VM that will become the template
qm create 9000 \
  --name "ubuntu-22-04-template" \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr1 \
  --tags "VM-Templates" \
  --pool "VM-Templates"

# Import the cloud image as the disk
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm

# Attach the imported disk
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Add cloud-init drive
qm set 9000 --ide2 local-lvm:cloudinit

# Set boot order to the disk
qm set 9000 --boot order=scsi0

# Enable serial console and agent
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# Convert to template
qm template 9000
```

- [ ] `infrastructure/vmbr1.tf` — automation VM, dns/vault/runner LXCs (cloned from the Packer golden image, see Phase 3)
- [ ] `infrastructure/vmbr2.tf` — docker-host, k3s-01, k3s-02 VMs
- [ ] Each resource sets: CPU cores, memory, disk size, network bridge, and static IP via cloud-init

```hcl
# VM Sample template
resource "proxmox_virtual_environment_vm" "automation" {
  name      = "automation"
  node_name = "pve"  # your Proxmox node's name

  clone {
    vm_id = 9000
  }

  cpu {
    cores = 2
  }
  memory {
    dedicated = 2048
  }

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

# LXC Container Template
resource "proxmox_virtual_environment_container" "dns" {
  node_name = "pve"
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

## 2.5 Provision

- [ ] `terraform init`
- [ ] `terraform plan` — review before applying
- [ ] `terraform apply`
- [ ] Confirm nodes exist and are reachable — with the SSH config from Phase 1.9, this now works directly, no manual jump or `-i`/`-J` flags needed:

```bash
# Updated Passwordless Authentication
  ssh 10.10.0.10   # automation VM

# Troubleshooting when unable to remotely connect to provisioned VM
ssh 192.168.1.150   # or ssh proxmox-node
qm guest exec 100 -- cat /home/automation/.ssh/authorized_keys
qm guest exec 100 -- cloud-init status --long

# Solution
terraform destroy -target=proxmox_virtual_environment_vm.automation_vm
ssh-keygen -R 10.10.0.10
terraform apply
ssh 10.10.0.10

```
