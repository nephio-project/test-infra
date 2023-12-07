module "gcp-ubuntu-focal" {
  source             = ".//modules/gcp"
  nephio_pkg_version = var.pkg_version
  nephio_e2e_type    = var.e2e_type
}

module "gcp-ubuntu-jammy" {
  source             = ".//modules/gcp"
  vmimage            = "ubuntu-os-cloud/ubuntu-2204-lts"
  nephio_pkg_version = var.pkg_version
  nephio_e2e_type    = var.e2e_type
}

module "gcp-fedora-34" {
  source             = ".//modules/gcp"
  vmimage            = "fedora-cloud/fedora-cloud-34"
  ansible_user       = "fedora"
  nephio_pkg_version = var.pkg_version
  nephio_e2e_type    = var.e2e_type
}

variable "pkg_version" {
  description = "The version used for all the nephio packages"
  default     = "main"
  type        = string
}

variable "e2e_type" {
  description = "The End-to-End testing type"
  default     = "free5gc"
  type        = string
}
