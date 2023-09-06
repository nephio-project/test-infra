module "gcp-ubuntu-focal" {
  source             = ".//modules/gcp"
  nephio_pkg_version = var.pkg_version
}

module "gcp-fedora-34" {
  source             = ".//modules/gcp"
  vmimage            = "fedora-cloud/fedora-cloud-34"
  ansible_user       = "fedora"
  nephio_pkg_version = var.pkg_version
}

variable "pkg_version" {
  description = "The version used for all the nephio packages"
  default     = "main"
  type        = string
}
