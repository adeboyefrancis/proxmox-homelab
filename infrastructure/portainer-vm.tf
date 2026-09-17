
# VM Clone configuration for Automation (Ansible, Git, CLI tools, GitHub Runner initially)
resource "proxmox_virtual_environment_vm" "portainer_vm" {
  name        = "portainer-vm"
  description = "Docker/Portainer host for automation and container management with Traefik reverse proxy"
  node_name   = var.node_name
  pool_id     = proxmox_virtual_environment_pool.workload.pool_id
  vm_id       = 101

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
    user_data_file_id = proxmox_virtual_environment_file.portainer_cloud_init_snippet.id

    # Static IP -- this VM is the Ansible control node; every inventory file,
    # SSH example, and SCP command elsewhere in the repo assumes 10.20.0.10
    ip_config {
      ipv4 {
        address = "10.20.0.10/24"
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
      username = "admin"
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
    "docker",
    "portainer",
    "traefik",
    "containers",
    "platform"
  ]

}


# Cloud-init user data snippet -- this is the authoritative source for both
# packages/setup AND user/SSH key creation (see note in user_account above:
# user_data_file_id overrides rather than merges with it).
resource "proxmox_virtual_environment_file" "portainer_cloud_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    file_name = "portainer-cloud-config.yaml"
    data = templatefile("${path.module}/templates/portainer-cloud-config.yaml", {
      ssh_key = var.ssh_public_key
    })
  }
}
