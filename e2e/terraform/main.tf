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

resource "google_compute_instance" "lab_instances" {
  count                     = var.nephio_lab_nodes
  name                      = "nephio-lab"
  machine_type              = var.instance
  allow_stopping_for_update = true
  metadata = {
    ssh-keys                = "${var.ansible_user}:${file(var.ssh_pub_key)}"
    metadata_startup_script = file("${path.module}/../provision/init.sh")
    nephio-run-e2e          = false
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
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
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
    destination = "/home/ubuntu/test-infra"
    connection {
      host        = self.network_interface[0].access_config[0].nat_ip
      type        = "ssh"
      private_key = file(var.ssh_prv_key)
      user        = var.ansible_user
      agent       = false
    }
  }
  provisioner "file" {
    source      = "/etc/nephio/nephio.yaml"
    destination = "/home/ubuntu/nephio.yaml"
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
      "cd /home/ubuntu/test-infra/e2e/provision/",
      "chmod +x init.sh",
      "sudo -E NEPHIO_REPO_DIR=/home/ubuntu/test-infra NEPHIO_DEBUG=true NEPHIO_RUN_E2E=true ./init.sh"
    ]
  }
}
