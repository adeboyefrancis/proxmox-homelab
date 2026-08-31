variable "access_key" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  type      = string
  sensitive = true
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "team" {
  type    = string
  default = "DevOps"
}

variable "owner" {
  type = string
}

variable "ami_name" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}