provider "google" {
    credentials = file("/etc/satoken/satoken")
    project = "pure-faculty-367518"
    region = "us-central1"
    zone = "us-central1-c"
}

module "e2e" {
  source = "../modules/e2e"
  vmimage = "fedora-cloud/fedora-cloud-34"
  home_user = "fedora"
  ansible_user = "fedora"
}
