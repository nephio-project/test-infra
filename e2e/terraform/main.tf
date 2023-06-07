provider "google" {
  project     = var.project
  region      = var.region
  zone        = var.zone
  credentials = file(var.credentials)
}

resource "random_string" "vm-name" {
  length  = 6
  upper   = false
  numeric = false
  lower   = true
  special = false
}

locals {
  vm-name = "e2e-vm-${random_string.vm-name.result}"
}

resource "google_compute_instance" "vm_instance" {
  name                      = local.vm-name
  machine_type              = var.instance
  allow_stopping_for_update = true
  metadata = {
    ssh-keys                = "${var.ansible_user}:${file(var.ssh_pub_key)}"
    metadata_startup_script = file("${path.module}/../provision/gce_init.sh")
    nephio-run-e2e          = true
  }
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 200
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

}

