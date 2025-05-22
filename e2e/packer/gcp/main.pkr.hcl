packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

# ------------------------
# Variables
# ------------------------

variable "image_version" {
  description = "Image version"
  type        = string
  default     = "1.0.1"
}

variable "machine_type" {
  description = "GCP flavor for CI instances"
  type        = string
  default     = "e2-standard-16"
}

variable "project_id" {
  description = "GCP project for hosting CI instances"
  type        = string
  default     = "pure-faculty-367518"
}

variable "source_image_family" {
  description = "Base OS image family"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "source_image_project_id" {
  description = "GCP project for base OS images"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "ssh_username" {
  description = "SSH username"
  type        = string
  default     = "ubuntu"
}

variable "zone" {
  description = "GCP zone for deploying instances"
  type        = string
  default     = "us-central1-c"
}

variable "image_ttl" {
  description = "Time-to-live label"
  type        = string
  default     = "48h"
}

# ------------------------
# Locals
# ------------------------

locals {
  datestamp     = formatdate("YYYYMMDD", timestamp())
  image_version = replace(var.image_version, ".", "-")
}

# ------------------------
# Source
# ------------------------

source "googlecompute" "nephio-packer" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = var.machine_type
  source_image_project_id = var.source_image_project_id
  source_image_family     = var.source_image_family
  ssh_username            = var.ssh_username
  use_os_login            = "false"
  disk_size               = 50
  credentials_file        = "/etc/satoken/satoken"
  image_name              = "nephio-pre-baked-${var.source_image_family}-${local.image_version}-${local.datestamp}"
  image_labels = {
    created_by = "prow"
    pr_number  = var.image_version
    ttl        = var.image_ttl
  }
}

# ------------------------
# Build
# ------------------------

build {
  sources = ["source.googlecompute.nephio-packer"]

  provisioner "file" {
    source      = "../../../../test-infra"
    destination = "/home/${var.ssh_username}/test-infra"
  }

  provisioner "file" {
    destination = "/home/${var.ssh_username}/timestamp.txt"
    content     = "${local.datestamp}"
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
