packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

# Requires Variables for GCP
variable "project_id" {}
variable "zone" {}
variable "source_image" {}
variable "image_version" {}
variable "machine_type" {}
variable "disk_size" {} 

locals {
    datestamp = formatdate("YYYYMMDD", timestamp())
    image_version = replace(var.image_version, ".", "-")
}

source "googlecompute" "nephio-packer" {
  project_id        = var.project_id
  zone              = var.zone
  machine_type      = var.machine_type
  source_image      = var.source_image
  ssh_username      = "ubuntu"
  use_os_login      = "false"
  disk_size         = var.disk_size
  image_name        = "nephio-pre-baked-${local.image_version}-ubuntu-${local.datestamp}"
  image_description = "Nephio pre-backed ubuntu 20.04 image"  

}

build {
  sources = ["sources.googlecompute.nephio-packer"]
  provisioner "shell" {
    expect_disconnect = "true"
    inline = [
      "echo '=============================================='",
      "echo 'APT INSTALL PACKAGES & UPDATES'",
      "echo '=============================================='",
      "sudo apt update",
      "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections",
      "sudo apt upgrade -y"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo 'INSTALL NEPHIO CORE'",
      "echo '=============================================='",
      "git clone https://github.com/nephio-project/test-infra.git",
      "cd test-infra/e2e/provision",
      "ANSIBLE_CMD_EXTRA_VAR_LIST='DEBUG=true' ./install_sandbox.sh",
      "echo '=============================================='",
      "echo 'BUILD COMPLETE'",
      "echo '=============================================='"
    ]
  }
}