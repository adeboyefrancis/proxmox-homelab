## LXC Containers
## LXC 201 - Technitium Internal DNS Container

resource "proxmox_virtual_environment_container" "technitium-dns" {
  node_name = var.node_name
  vm_id     = 201
  tags      = ["LXCs", "Technitium", "DNS", "Internal"]

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
    size         = 4 # GB
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
    user_account {
      keys = [var.ssh_public_key]
      password = var.lxc_password
    }
  }
}