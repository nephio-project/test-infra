module "gcp-ubuntu-focal" {
  source               = ".//modules/gcp"
  nephio_e2e_type      = var.e2e_type
  nephio_e2e_fail_fast = var.fail_fast
  nephio_mgmt_cluster_type = var.mgmt_cluster_type
}

module "gcp-ubuntu-jammy" {
  source               = ".//modules/gcp"
  vmimage              = "ubuntu-os-cloud/ubuntu-2204-lts"
  nephio_e2e_type      = var.e2e_type
  nephio_e2e_fail_fast = var.fail_fast
  nephio_mgmt_cluster_type = var.mgmt_cluster_type
}

module "gcp-fedora-34" {
  source               = ".//modules/gcp"
  vmimage              = "fedora-cloud/fedora-cloud-34"
  ansible_user         = "fedora"
  nephio_e2e_type      = var.e2e_type
  nephio_e2e_fail_fast = var.fail_fast
  nephio_mgmt_cluster_type = var.mgmt_cluster_type
}

module "gcp-fedora-38" {
  source               = ".//modules/gcp"
  vmimage              = "fedora-cloud/fedora-cloud-38"
  ansible_user         = "fedora"
  nephio_e2e_type      = var.e2e_type
  nephio_e2e_fail_fast = var.fail_fast
  nephio_mgmt_cluster_type = var.mgmt_cluster_type
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

variable "mgmt_cluster_type" {
  description = "Defines the type of k8s cluster"
  default     = "kind"
  type        = string
}
