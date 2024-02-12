terraform {
  required_providers {
    random = "~> 3.5"
    google = "~> 4.80"
  }
}

provider "google" {
  credentials = file(var.credentials)
  project     = var.project
  region      = var.region
  zone        = var.zone
}

resource "random_string" "vm-name" {
  length  = 6
  upper   = false
  numeric = false
  lower   = true
  special = false
}

locals {
  vm-name    = "e2e-vm-${random_string.vm-name.result}"
}

resource "google_compute_instance" "lab_instances" {
  count                     = var.nephio_lab_nodes
  name                      = "nephio-lab"
  machine_type              = var.instance
  allow_stopping_for_update = true
  metadata = {
    ssh-keys                = "${var.ansible_user}:${file(var.ssh_pub_key)}"
    metadata_startup_script = file("${path.module}/../../../provision/init.sh")
    nephio-run-e2e          = false
  }
  boot_disk {
    initialize_params {
      image = var.vmimage
      size  = 200
    }
  }
  network_interface {
    network = "default"
    access_config {
    }
  }
}

resource "google_compute_instance" "e2e_instances" {
  count                     = var.nephio_e2e_nodes
  name                      = local.vm-name
  machine_type              = var.instance
  allow_stopping_for_update = true
  metadata = {
    ssh-keys = "${var.ansible_user}:${file(var.ssh_pub_key)}"
  }
  boot_disk {
    initialize_params {
      image = var.vmimage
      size  = 200
    }
  }
  network_interface {
    network = "default"
    access_config {
    }
  }
  provisioner "file" {
    source      = "../../../test-infra"
    destination = "/home/${var.ansible_user}/test-infra"
    connection {
      host        = self.network_interface[0].access_config[0].nat_ip
      type        = "ssh"
      private_key = file(var.ssh_prv_key)
      user        = var.ansible_user
      agent       = false
    }
  }
  provisioner "remote-exec" {
    connection {
      host        = self.network_interface[0].access_config[0].nat_ip
      type        = "ssh"
      private_key = file(var.ssh_prv_key)
      user        = var.ansible_user
      agent       = false
    }
    inline = [
      "! command -v dnf > /dev/null || sudo -- sh -c 'dnf update kernel-core -y; shutdown -r +1'"
    ]
  }
  provisioner "remote-exec" {
    connection {
      host        = self.network_interface[0].access_config[0].nat_ip
      type        = "ssh"
      private_key = file(var.ssh_prv_key)
      user        = var.ansible_user
      agent       = false
    }
    inline = [
      "cd /home/${var.ansible_user}/test-infra/e2e/provision/",
      "chmod +x init.sh",
      "sudo -E FAIL_FAST=${var.nephio_e2e_fail_fast} E2ETYPE=${var.nephio_e2e_type} NEPHIO_REPO_DIR=/home/${var.ansible_user}/test-infra NEPHIO_DEBUG=true NEPHIO_RUN_E2E=true NEPHIO_USER=${var.ansible_user} ./init.sh"
    ]
  }
}
