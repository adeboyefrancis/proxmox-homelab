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
    # Attach the package/runcmd snippet to the VM via cloud-init
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_snippet.id

    # Static IP -- this VM is the Ansible control node; every inventory file, playbook, and role will reference this IP address.
    ip_config {
      ipv4 {
        address = "10.10.0.10/24"
        gateway = "10.10.0.1"
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


# Cloud-init user data snippet -- packages and setup only.
resource "proxmox_virtual_environment_file" "cloud_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    file_name = "cloud-init-vm.yml"
    data      = <<-EOF
      # Automation VM Cloud-Init Configuration
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

      runcmd:
        - echo "Automation VM setup complete!"    
    EOF
  }
}