packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

variable "image_version" {
  description = "Image version"
  default     = "1.0.0"
  type        = string
}

variable "project_id" {
  description = "GCP project that will host CI instances"
  default     = "pure-faculty-367518"
  type        = string
}

variable "zone" {
  description = "GCP zone to deploy CI instances"
  default     = "us-central1-c"
  type        = string
}

variable "machine_type" {
  description = "GCP flavor to be used by the CI instances"
  default     = "e2-standard-16"
  type        = string
}

variable "source_image_project_id" {
  description = "OS image project ID to be used for the creation of CI instances"
  default     = "ubuntu-os-cloud"
  type        = string
}

variable "source_image_family" {
  description = "OS image family to be used for the creation of CI instances"
  default     = "ubuntu-2004-lts"
  type        = string
}

variable "ssh_username" {
  description = "OS user used for SSH connectivity"
  default     = "ubuntu"
  type        = string
}

locals {
  datestamp     = formatdate("YYYYMMDD", timestamp())
  image_version = replace(var.image_version, ".", "-")
}

source "googlecompute" "nephio-packer" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = var.machine_type
  source_image_project_id = [var.source_image_project_id]
  source_image_family     = var.source_image_family
  ssh_username            = var.ssh_username
  use_os_login            = "false"
  disk_size               = 50
  image_name              = "nephio-pre-baked-${local.image_version}-${var.source_image_family}-${local.datestamp}"
  credentials_file        = "/etc/satoken/satoken"
}

build {
  sources = ["sources.googlecompute.nephio-packer"]
  provisioner "file" {
    source      = "../../../../test-infra"
    destination = "/home/${var.ssh_username}/test-infra"
  }

  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo 'INSTALL NEPHIO CORE'",
      "echo '=============================================='",
      "cd test-infra/e2e/provision",
      "ANSIBLE_CMD_EXTRA_VAR_LIST='DEBUG=true' ./install_sandbox.sh",
      "echo '=============================================='",
      "echo 'BUILD COMPLETE'",
      "echo '=============================================='"
    ]
  }
}
