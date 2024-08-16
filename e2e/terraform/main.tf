module "gcp-ubuntu-focal" {
  source               = ".//modules/gcp"
  nephio_e2e_type      = var.e2e_type
  nephio_e2e_fail_fast = var.fail_fast
}

module "gcp-ubuntu-jammy" {
  source               = ".//modules/gcp"
  vmimage              = "ubuntu-os-cloud/ubuntu-2204-lts"
  nephio_e2e_type      = var.e2e_type
  nephio_e2e_fail_fast = var.fail_fast
}

module "gcp-fedora-34" {
  source               = ".//modules/gcp"
  vmimage              = "fedora-cloud/fedora-cloud-34"
  ansible_user         = "fedora"
  nephio_e2e_type      = var.e2e_type
  nephio_e2e_fail_fast = var.fail_fast
}

variable "e2e_type" {
  description = "The End-to-End testing type"
  default     = "free5gc"
  type        = string
}

variable "fail_fast" {
  description = "Defines the behavior after failing a testing"
  default     = "false"
  type        = string
}
