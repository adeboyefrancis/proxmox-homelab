## LXC Containers
## LXC 201 - Technitium Internal DNS Container

resource "proxmox_virtual_environment_container" "technitium-dns" {
  node_name = var.node_name
  vm_id     = 201
  tags      = ["lxcs", "technitium", "dns", "internal"]

  unprivileged = true # best practice for LXCs unless you specifically need privileged features
  
  features {
    nesting = true # required for running Docker inside an LXC
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512 # between 512MB and 1GB -- adjust up to 2048 if Technitium feels sluggish
  }

  disk {
    datastore_id = "local-lvm"
    size         = 4 # Dedicated space between 4GB and 8GB
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr1"
  }

  initialization {
    hostname = "technitium-dns"

    ip_config {
      ipv4 {
        address = "10.10.0.20/24"
        gateway = "10.10.0.1"
      }
    }

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }
}

## ============================================================================
## LXC 202 - HashiCorp Vault Container ( Secret Management )
## ============================================================================
resource "proxmox_virtual_environment_container" "hashicorp-vault" {
  node_name = var.node_name
  vm_id     = 202
  tags      = ["lxcs", "vault", "security", "automation", "secrets", "management"]

  unprivileged = true 
  
  features {
    nesting = true 
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 1 # Vault is lightweight for a homelab
  }

  memory {
    dedicated = 512 # 512MB - 1GB is a safe starting point for Vault memory allocation
  }

  disk {
    datastore_id = "local-lvm"
    size         = 4 # 4GB leaves room for secrets and storage backends
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr1"
  }

  initialization {
    hostname = "hcp-vault"

    ip_config {
      ipv4 {
        address = "10.10.0.30/24" # Static IP for Vault to ensure consistent access
        gateway = "10.10.0.1"
      }
    }

    dns {
      servers = [var.dns_server, "8.8.8.8", "1.1.1.1"]
    }
    
    user_account {
      keys     = [var.ssh_public_key]
      password = var.lxc_password
    }
  }
}

## ============================================================================
## LXC 203 - GitHub Actions Runner Container
## ============================================================================
resource "proxmox_virtual_environment_container" "github-ci-runner" {
  node_name = var.node_name
  vm_id     = 203
  tags      = ["lxcs", "ci-cd", "github", "automation", "runner"]

  unprivileged = true 
  
  features {
    nesting = true # Essential if your GitHub workflows run Docker-in-Docker (DinD)
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 2 # Boosted CPU cores to handle build and compilation tasks faster
  }

  memory {
    dedicated = 2048 # 2GB RAM minimum for building software/packages
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 10 # 10GB given for checking out source code and caching dependencies
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr1"
  }

  initialization {
    hostname = "github-ci-runner"

    ip_config {
      ipv4 {
        address = "10.10.0.40/24" # Static IP for the CI runner to ensure consistent access
        gateway = "10.10.0.1"
      }
    }

    dns {
      servers = [var.dns_server, "8.8.8.8", "1.1.1.1"]
    }

    user_account {
      keys     = [var.ssh_public_key]
      password = var.lxc_password
    }
  }
}