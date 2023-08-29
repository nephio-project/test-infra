module "gcp-ubuntu-focal" {
  source = ".//modules/gcp"
}

module "gcp-fedora-34" {
  source       = ".//modules/gcp"
  vmimage      = "fedora-cloud/fedora-cloud-34"
  ansible_user = "fedora"
}
