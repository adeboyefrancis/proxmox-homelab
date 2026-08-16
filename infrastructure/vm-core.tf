# VM Clone configuration for Automation (Ansible, Git, CLI tools, GitHub Runner initially)
resource "proxmox_virtual_environment_vm" "automation_vm" {
  name      = "automation-vm"
  node_name = var.node_name
  pool_id   = proxmox_virtual_environment_pool.automation.pool_id
  vm_id     = 100

  clone {
    vm_id = var.vm_template_id
    full  = false # Fast linked clone -- fine while iterating; switch to full=true once the template stabilizes
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
    # Attach the package/runcmd snippet defined below
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_snippet.id

    # Static IP -- this VM is the Ansible control node; every inventory file,
    # SSH example, and SCP command elsewhere in the repo assumes 10.10.0.10
    ip_config {
      ipv4 {
        address = "10.10.0.10/24"
        gateway = "10.10.0.1"
      }
    }

    # Single source of truth for network config. NOTE: user identity is defined
    # in the snippet below, not here -- when user_data_file_id is set, Proxmox
    # uses that file as the entire user-data payload instead of merging it with
    # user_account, so user_account below is effectively inert. Kept only as
    # a Proxmox-UI-visible record of intent; the snippet is what actually runs.
    user_account {
      username = "automation"
      keys = [
        var.ssh_public_key
      ]
    }
  }

  boot_order = ["scsi0"]
  started    = true

  lifecycle {
    ignore_changes = [started]
  }

  tags = [
    "Automation",
    "VMs"
  ]

}


# Cloud-init user data snippet -- this is the authoritative source for both
# packages/setup AND user/SSH key creation (see note in user_account above:
# user_data_file_id overrides rather than merges with it).
resource "proxmox_virtual_environment_file" "cloud_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    file_name = "cloud-init-vm.yml"
    data = <<-EOF
      #cloud-config
      # ^ REQUIRED first line -- without it, cloud-init discards the entire
      # file as "unhandled non-multipart userdata" and nothing below runs,
      # including user creation.
      package_update: true
      packages:
        - git
        - curl
        - htop
        - btop
        - make
        - ansible
        - python3
        - python3-pip
        - jq

      users:
        - name: automation
          groups: sudo
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh_authorized_keys:
            - ${var.ssh_public_key}

      runcmd:
        - echo "Automation VM setup complete!"
    EOF
  }
}