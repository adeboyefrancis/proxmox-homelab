# Variables for the build
variable "subscription_id" {
  type    = string
  default = env("ARM_SUBSCRIPTION_ID")
}

variable "client_id" {
  type    = string
  default = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type      = string
  sensitive = true
  default   = env("ARM_CLIENT_SECRET")
}

variable "tenant_id" {
  type    = string
  default = env("ARM_TENANT_ID")
}

variable "image_version" {
  type    = string
  default = "1.0.0"
}

variable "location" {
  type    = string
  default = "centralus"
}

variable "resource_group" {
  type = string
}

variable "gallery_name" {
  type = string
}

/*
variable "temp_resource_group" {
  type = string
}
*/

variable "owner" {
  type = string
}

variable "bucket_name" {
    type = string
}

variable "team" {
    type = string
}