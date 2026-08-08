# VM Clone configuration for Automation (Packer, Ansible, Git, etc.)
resource "proxmox_virtual_environment_vm" "automation_vm" {
  name      = "automation-vm"
  node_name = "devlab"
  pool_id   = proxmox_virtual_environment_pool.automation.pool_id
  vm_id     = 100

  clone {
    vm_id = var.vm_template_id
    full  = false # Fast linked clone
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr1"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # Cloud-Init Initialization
  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "automation"
      keys = [
        var.ssh_public_key
      ]
    }
  }

  boot_order = ["scsi0"]
  started    = true

  tags = [
    "Automation",
    "VMs"
  ]

}