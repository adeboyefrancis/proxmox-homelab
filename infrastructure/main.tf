terraform {
  required_version = ">= 1.15.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111.1"
    }
  }
# HCP Remote Backend Configuration - Using CLI workflow to authenticate with HCP and store state remotely
  cloud {
    organization = "touchedbyfrancisblog"

    workspaces {
      name = "devlab-home"
    }
  }
}

# Configure provider options (using variables or environment defaults)
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}