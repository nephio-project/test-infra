provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
  credentials = "${file(var.credentials)}"
}

resource "random_string" "vm-name" {
  length  = 6
  upper   = false
  numeric  = false
  lower   = true
  special = false
}

locals {
  vm-name = "e2e-vm-${random_string.vm-name.result}"
}

resource "google_compute_instance" "vm_instance" {
  name         = local.vm-name
  machine_type = var.instance
  allow_stopping_for_update = true
  metadata = {
  ssh-keys = "${var.ansible_user}:${file(var.ssh_pub_key)}"
  }
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 60
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
  provisioner "file" {
    source      = "../provision"
    destination = "/home/ubuntu/provision"
    connection {
    host        = self.network_interface[0].access_config[0].nat_ip
    type        = "ssh"
    private_key = "${file(var.ssh_prv_key)}"
    user        = "${var.ansible_user}"
    agent       = false
  }

  }

  provisioner "file" {
    source      = "/etc/nephio/nephio.yaml"
    destination = "/home/ubuntu/nephio.yaml"
    connection {
    host        = self.network_interface[0].access_config[0].nat_ip
    type        = "ssh"
    private_key = "${file(var.ssh_prv_key)}"
    user        = "${var.ansible_user}"
    agent       = false
  }

  }

  provisioner "remote-exec" {
    connection {
    host        = self.network_interface[0].access_config[0].nat_ip
    type        = "ssh"
    private_key = "${file(var.ssh_prv_key)}"
    user        = "${var.ansible_user}"
    agent       = false
  }
    inline = [
               "cd provision/",
               "chmod +x gce_run.sh",
               "DEBUG=true DEPLOYMENT_TYPE=cluster-api ./gce_run.sh"
              ]
  }

}

