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