provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
  credentials = "${file(var.credentials)}"
}

resource "google_compute_instance" "vm_instance" {
  name         = "e2e-instance"
  machine_type = var.instance
  allow_stopping_for_update = true
  metadata = {
  ssh-keys = "${var.ansible_user}:${file(var.ssh_pub_key)}"
  }
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
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
               "chmod +x provision/gce_run.sh",
               "provision/gce_run.sh"
              ]
  }

}

