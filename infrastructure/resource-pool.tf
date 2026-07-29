# --- Resource Pools Definition ---
resource "proxmox_virtual_environment_pool" "management" {
  pool_id = "Management"
  comment = "Core Services (Vault, Registry, DNS)-10.10.0.0/24)"
}

resource "proxmox_virtual_environment_pool" "automation" {
  pool_id = "Automation"
  comment = "CI/CD & Provisioning (Ansible, Packer, Runners)-10.10.0.0/24)"
}

resource "proxmox_virtual_environment_pool" "platform" {
  pool_id = "Platform"
  comment = "Platform Controllers (K3s, ArgoCD, Observability)-10.20.0.0/24)"
}

resource "proxmox_virtual_environment_pool" "workload" {
  pool_id = "Workload"
  comment = "Application Runtimes & Docker Hosts-10.20.0.0/24)"
}

resource "proxmox_virtual_environment_pool" "vm-templates" {
  pool_id = "VM-Templates"
  comment = "Base VM Templates for Core Services, Platform & Workload"
}

resource "proxmox_virtual_environment_pool" "lxc-templates" {
  pool_id = "LXC-Templates"
  comment = "LXC Templates for Core Services, Platform & Workload"
}