packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.1.8, < 2.0.0"
    }
  }
}

# ============================================================
# VARIABLES
# ============================================================

variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API endpoint."
}

variable "proxmox_api_token_id" {
  type        = string
  sensitive   = true
  description = "Proxmox API token ID."
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret."
}

variable "node_name" {
  type        = string
  description = "Proxmox node where the template will be built."
}

variable "template_vm_id" {
  type        = number
  description = "Proxmox VM ID used to create the golden image."
}

variable "template_name" {
  type        = string
  default     = "ubuntu-golden-template"
  description = "Name of the resulting Proxmox template."
}

variable "template_description" {
  type        = string
  default     = "Ubuntu 22.04 golden image built and sealed by Packer for Terraform cloning."
  description = "Description of the Proxmox golden image."
}

# ============================================================
# GUEST SSH
# ============================================================

variable "ssh_username" {
  type        = string
  description = "SSH username created inside the Ubuntu VM."
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "SSH password for the Ubuntu VM."
}

# ============================================================
# SSH BASTION
# ============================================================

variable "ssh_bastion_host" {
  type        = string
  description = "Hostname or IP address of the SSH bastion."
}

variable "ssh_bastion_username" {
  type        = string
  description = "SSH username for the bastion."
}

variable "ssh_bastion_password" {
  type        = string
  sensitive   = true
  description = "SSH password for the bastion."
}

# ============================================================
# PROXMOX UBUNTU GOLDEN IMAGE
# ============================================================

source "proxmox-iso" "ubuntu_golden" {

  # ----------------------------------------------------------
  # Proxmox API
  # ----------------------------------------------------------

  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = false

  # ----------------------------------------------------------
  # VM Identity
  # ----------------------------------------------------------

  node  = var.node_name
  vm_id = var.template_vm_id

  vm_name              = var.template_name
  template_description = var.template_description

  tags = "Packer;VM-Templates;Ubuntu;Golden-Image"

  # ----------------------------------------------------------
  # Ubuntu ISO
  # ----------------------------------------------------------

  boot_iso {
    type             = "scsi"
    iso_file         = "local:iso/ubuntu-22.04.5-live-server-amd64.iso"
    iso_storage_pool = "local"

    iso_checksum = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"

    unmount = true
  }

  # ----------------------------------------------------------
  # VM Hardware
  # ----------------------------------------------------------

  cores           = 2
  memory          = 2048
  scsi_controller = "virtio-scsi-pci"

  # ----------------------------------------------------------
  # Disk
  # ----------------------------------------------------------

  disks {
    disk_size    = "20G"
    storage_pool = "local-lvm"
    type         = "scsi"
  }

  # ----------------------------------------------------------
  # Network
  # ----------------------------------------------------------

  network_adapters {
    bridge = "vmbr1"
    model  = "virtio"
  }

  # ----------------------------------------------------------
  # QEMU Guest Agent
  # ----------------------------------------------------------

  qemu_agent = true

  # ----------------------------------------------------------
  # Packer HTTP Server
  # ----------------------------------------------------------

  http_directory = "http"

  http_port_min = 8100
  http_port_max = 8199

  # ----------------------------------------------------------
  # Ubuntu Autoinstall
  # ----------------------------------------------------------

  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]

  boot         = "c"
  boot_wait    = "6s"
  communicator = "ssh"


  # ----------------------------------------------------------
  # SSH Bastion / Jump Host
  # ----------------------------------------------------------

  ssh_bastion_host     = var.ssh_bastion_host
  ssh_bastion_port     = 22
  ssh_bastion_username = var.ssh_bastion_username
  ssh_bastion_password = var.ssh_bastion_password

  # ----------------------------------------------------------
  # Guest SSH
  # ----------------------------------------------------------

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password

  ssh_timeout            = "40m"
  ssh_handshake_attempts = 100

  # ----------------------------------------------------------
  # Proxmox Template
  # ----------------------------------------------------------

  template_name = var.template_name
}

# ============================================================
# BUILD
# ============================================================

build {
  name    = "ubuntu-golden-build"
  sources = ["source.proxmox-iso.ubuntu_golden"]

  # ==========================================================
  # WAIT FOR CLOUD-INIT
  # ==========================================================

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait",
      "echo 'Cloud-init completed.'"
    ]

    max_retries = 3
  }

  # ==========================================================
  # SYSTEM UPDATE
  # ==========================================================

  provisioner "shell" {
    inline = [
      "echo 'Updating package repositories...'",
      "sudo apt-get update",

      "echo 'Applying system updates...'",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",

      "echo 'System update completed.'"
    ]

    max_retries = 3
  }

  # ==========================================================
  # BASE PACKAGES
  # ==========================================================

  provisioner "shell" {
    inline = [
      "echo 'Installing base packages...'",

      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y qemu-guest-agent openssh-server curl wget git vim python3 python3-pip ca-certificates gnupg lsb-release jq htop",

      "echo 'Enabling QEMU Guest Agent...'",
      "sudo systemctl enable --now qemu-guest-agent",

      "echo 'Base packages installed.'"
    ]

    max_retries = 3
  }

  # ==========================================================
  # IMAGE CLEANUP
  # ==========================================================

  provisioner "shell" {
    script = "scripts/cleanup.sh"

    execute_command = "sudo bash '{{.Path}}'"

    max_retries = 2
  }

  # ==========================================================
  # BUILD MANIFEST
  # ==========================================================

  post-processor "manifest" {
    output = "manifest.json"
  }
}