## Control Node VM

resource "proxmox_virtual_environment_vm" "k3_control_node" {
  name        = "k3-control-node"
  description = "K3s Control Node for lightweight Kubernetes cluster management"
  node_name   = var.node_name
  pool_id     = proxmox_virtual_environment_pool.platform.pool_id
  vm_id       = 102

  clone {
    vm_id = var.vm_template_id # points at the Packer-built golden image (vm_id 9000) -- see automation/packer/
    full  = false              # Fast linked clone -- fine while iterating; switch to full=true once your workflow stabilizes
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    size         = 30
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr2"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # Cloud-Init Initialization
  initialization {
    # Attach the package/runcmd snippet defined below
    user_data_file_id = proxmox_virtual_environment_file.platform_cloud_init_snippet.id

    # Static IP -- this VM is the Ansible control node; every inventory file,
    # SSH example, and SCP command elsewhere in the repo assumes 10.20.0.20
    ip_config {
      ipv4 {
        address = "10.20.0.20/24"
        gateway = "10.20.0.1"
      }
    }

    dns {
      servers = [var.dns_server, "8.8.8.8", "1.1.1.1"]
    }

    # Single source of truth for network config. NOTE: user identity is defined
    # in the snippet below, not here -- when user_data_file_id is set, Proxmox
    # uses that file as the entire user-data payload instead of merging it with
    # user_account, so user_account below is effectively inert. Kept only as
    # a Proxmox-UI-visible record of intent; the snippet is what actually runs.
    user_account {
      username = "platform"
      keys = [
        var.ssh_public_key
      ]
    }
  }

  boot_order = ["scsi0"]
  started    = true

  # Lets you manually shut this VM down when not in use without Terraform
  # powering it back on the next time you `apply` for an unrelated resource
  # (e.g. provisioning a new LXC). Start it back up manually when needed.
  lifecycle {
    ignore_changes = [started, pool_id]
  }

  tags = [
    "platform",
    "vms",
    "k3s",
    "control-node"
  ]

}

resource "proxmox_virtual_environment_file" "platform_cloud_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    file_name = "platform-cloud-init-vm.yml"
    data      = <<EOF
      #cloud-config
      # ^ REQUIRED first line -- without it, cloud-init discards the entire
      # file as "unhandled non-multipart userdata" and nothing below runs,
      # including user creation.

      hostname: k3-control-node
      manage_etc_hosts: true

      package_update: true
      packages:
        - btop
        - net-tools
        - curl


      users:
        - name: platform
          groups: sudo
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh_authorized_keys:
            - ${var.ssh_public_key}

      runcmd:
        - echo "Control Node VM setup complete!"
    EOF
  }
}



## Worker Node VM

resource "proxmox_virtual_environment_vm" "k3_worker_node" {
  name        = "k3-worker-node"
  description = "K3s Worker Node for Workload execution"
  node_name   = var.node_name
  pool_id     = proxmox_virtual_environment_pool.workload.pool_id
  vm_id       = 103

  clone {
    vm_id = var.vm_template_id # points at the Packer-built golden image (vm_id 9000) -- see automation/packer/
    full  = false              # Fast linked clone -- fine while iterating; switch to full=true once your workflow stabilizes
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr2"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # Cloud-Init Initialization
  initialization {
    # Attach the package/runcmd snippet defined below
    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init_snippet.id

    # Static IP -- this VM is the Ansible control node; every inventory file,
    # SSH example, and SCP command elsewhere in the repo assumes 10.20.0.20
    ip_config {
      ipv4 {
        address = "10.20.0.21/24"
        gateway = "10.20.0.1"
      }
    }

    dns {
      servers = [var.dns_server, "8.8.8.8", "1.1.1.1"]
    }

    # Single source of truth for network config. NOTE: user identity is defined
    # in the snippet below, not here -- when user_data_file_id is set, Proxmox
    # uses that file as the entire user-data payload instead of merging it with
    # user_account, so user_account below is effectively inert. Kept only as
    # a Proxmox-UI-visible record of intent; the snippet is what actually runs.
    user_account {
      username = "worker"
      keys = [
        var.ssh_public_key
      ]
    }
  }

  boot_order = ["scsi0"]
  started    = true

  # Lets you manually shut this VM down when not in use without Terraform
  # powering it back on the next time you `apply` for an unrelated resource
  # (e.g. provisioning a new LXC). Start it back up manually when needed.
  lifecycle {
    ignore_changes = [started, pool_id]
  }

  tags = [
    "workload",
    "vms",
    "k3s",
    "worker-node"
  ]

}

resource "proxmox_virtual_environment_file" "worker_cloud_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    file_name = "workload-cloud-init-vm.yml"
    data      = <<EOF
      #cloud-config
      # ^ REQUIRED first line -- without it, cloud-init discards the entire
      # file as "unhandled non-multipart userdata" and nothing below runs,
      # including user creation.

      hostname: k3-worker-node
      manage_etc_hosts: true

      package_update: true
      packages:
        - btop
        - net-tools
        - curl


      users:
        - name: worker
          groups: sudo
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh_authorized_keys:
            - ${var.ssh_public_key}

      runcmd:
        - echo "Worker Node VM setup complete!"
    EOF
  }
}
