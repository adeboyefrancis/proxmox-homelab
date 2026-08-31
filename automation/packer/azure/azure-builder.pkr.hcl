# Azure HCP Plugins
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.0"
    }
  }
}

# Source block defines the base image and Azure configuration
source "azure-arm" "ubuntu" {
  # Authentication
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id

  # Base image - Ubuntu 22.04 LTS
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  # Build VM configuration
  location = var.location
  vm_size  = "Standard_B1s"

  # Publish to Azure Compute Gallery
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.resource_group
    gallery_name         = var.gallery_name
    image_name           = "ubuntu-server"
    image_version        = var.image_version
    storage_account_type = "Standard_LRS"
  }

  # Temporary resource group for the build process
  # build_resource_group_name = var.temp_resource_group

  # Azure tags for the image
  azure_tags = {
    "built-by"   = "packer"
    "os"         = "ubuntu-22.04"
    "version"    = var.image_version
    "build-date" = local.timestamp
  }
}

# Build steps

hcp_packer_registry {
  bucket_name = var.bucket_name
  description = "Azure Sandbox POC Golden Image"

  bucket_labels = {
    "owner"          = var.owner
    "os"             = "Ubuntu"
    "ubuntu-version" = "22_04-lts"
    "team"           = var.team
    "build-time"     = local.timestamp
    "build-source"   = basename(path.cwd)
  }
}

build {
  sources = ["source.azure-arm.ubuntu"]

  # Wait for cloud-init to finish before making changes
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait"
    ]
  }

  # Update the system and install base packages
  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y curl wget vim htop unzip jq net-tools",
      "sudo apt-get install -y ca-certificates gnupg lsb-release"
    ]
  }

  # Install Docker
  provisioner "shell" {
    inline = [
      "# Add Docker's official GPG key and repository",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      "sudo systemctl enable docker"
    ]
  }

  # Install monitoring prerequisites
  provisioner "shell" {
    inline = [
      "# Azure Monitor Agent is installed as a VM extension after deployment",
      "sudo apt-get install -y rsyslog"
    ]
  }

  # Clean up before capture to reduce image size
  provisioner "shell" {
    execute_command = local.execute_command
    skip_clean      = true
    inline = [
      "apt-get clean",
      "rm -rf /var/lib/apt/lists/*",

      "# Deprovision the VM for generalization",
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
  }
}