## Resource Outputs
output "management_pool_id" {
  value       = proxmox_virtual_environment_pool.management.pool_id
  description = "The ID of the Management resource pool"
}

output "automation_pool_id" {
  value       = proxmox_virtual_environment_pool.automation.pool_id
  description = "The ID of the Automation resource pool"
}

output "platform_pool_id" {
  value       = proxmox_virtual_environment_pool.platform.pool_id
  description = "The ID of the Platform resource pool"
}

output "workload_pool_id" {
  value       = proxmox_virtual_environment_pool.workload.pool_id
  description = "The ID of the Workload resource pool"
}

output "vm_templates_pool_id" {
  value       = proxmox_virtual_environment_pool.vm-templates.pool_id
  description = "The ID of the VM Templates resource pool"
}

output "lxc_templates_pool_id" {
  value       = proxmox_virtual_environment_pool.lxc-templates.pool_id
  description = "The ID of the LXC Templates resource pool"
}
