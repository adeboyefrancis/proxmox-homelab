# Variables for Terraform configuration
variable "proxmox_endpoint" {
  description = "The endpoint for the Proxmox VE API"
  type        = string
}

variable "proxmox_api_token" {
  description = "The API token for authenticating with Proxmox VE"
  type        = string
}

variable "proxmox_insecure" {
  description = "Whether to skip SSL certificate verification"
  type        = bool
}

variable "proxmox_tags" {
  type        = list(string)
  description = "Global list of available Proxmox tags"
  default     = []
}

# variable "proxmox_password" {
#   description = "The password for the Proxmox VE API (used for SSH authentication)"
#   type        = string
# }

variable "node_name" {
  description = "The name of the Proxmox node where the VM will be created"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS servers to be used by the VM"
  type        = list(string)
}

variable "default_gateway_vmbr1" {
  description = "Default gateway for vmbr1"
  type        = string
}

variable "default_gateway_vmbr2" {
  description = "Default gateway for vmbr2"
  type        = string
}

variable "vm_template_id" {
  description = "The ID for the VM template to be created"
  type        = number
}

variable "vm_template_name" {
  description = "The name of the VM template to be created"
  type        = string
}

variable "ssh_public_key" {
  description = "The public SSH key to be injected into the VM template via cloud-init"
  type        = string
}

variable "ssh_key_path" {
  description = "The path to the SSH private key for accessing the VM template"
  type        = string
}

variable "lxc_password" {
  description = "The password for the LXC containers"
  type        = string
}