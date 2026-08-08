##################################################
# Baseline VM Template Cloud-Init Configuration
##################################################

# Download the cloud-init ISO image for Ubuntu
# resource "proxmox_download_file" "ubuntu_vm_template_iso" {
#   content_type = "iso"
#   datastore_id = "local"
#   node_name    = var.node_name
#   url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
# }

