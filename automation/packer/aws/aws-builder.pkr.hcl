## AWS Plugins 

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# --- Source Block ---
source "amazon-ebs" "base" {
  access_key    = var.access_key
  secret_key    = var.secret_key
  region        = var.region
  instance_type = "t2.micro"
  ssh_username  = "ubuntu"
  ami_name      = "${var.ami_name}-${local.timestamp}"
  vpc_id        = var.vpc_id
  subnet_id     = var.subnet_id

  associate_public_ip_address = true

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
}

# --- Build Block ---
hcp_packer_registry {
  bucket_name = var.bucket_name
  description = "AWS Sandbox POC Golden Image"

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
  name    = "${var.ami_name}"
  sources = ["source.amazon-ebs.base"]

  # System updates, essential packages, and Nginx deployment
  provisioner "shell" {
    execute_command = local.execute_command
    inline = [
      "apt-get update",
      "apt-get upgrade -y",
      "apt-get install -y ca-certificates curl gnupg lsb-release jq unzip htop vim",
      "echo 'Installing nginx...'",
      "sleep 10",
      "apt-get update",
      "apt-get install nginx -y",
      "systemctl enable nginx",
      "systemctl start nginx",
      "ufw allow 22/tcp",
      "ufw allow 80/tcp",
      "ufw allow 443/tcp",
      "echo 'y' | ufw enable"
    ]
  }

  post-processor "manifest" {
    output     = "base-manifest.json"
    strip_path = true
  }
}
