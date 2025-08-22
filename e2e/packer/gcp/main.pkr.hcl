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
  datestamp         = formatdate("YYYYMMDD", timestamp())
  sanitized_version = regex_replace(var.image_version, "[^a-zA-Z0-9_-]", "-")
  image_version     = lower(replace(local.sanitized_version, ".", "-"))
}

# ------------------------
# Source
# ------------------------

source "googlecompute" "nephio-packer" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = var.machine_type
  source_image_project_id = [var.source_image_project_id]
  source_image_family     = var.source_image_family
  ssh_username            = var.ssh_username
  use_os_login            = "false"
  disk_size               = 50
  credentials_file        = "/etc/satoken/satoken"
  image_name              = "nephio-pre-baked-${var.source_image_family}-${local.image_version}-${local.datestamp}"
  image_labels = {
    created_by = "prow"
    pr_number  = local.image_version
    ttl        = var.image_ttl
  }
}

# ------------------------
# Build
# ------------------------

build {
  sources = ["source.googlecompute.nephio-packer"]

  # ------------------------
  # Fix apt / command-not-found issue
  # ------------------------
  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo 'Fixing apt command-not-found issue...'",
      "echo '=============================================='",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo apt-get clean",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update || true",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils || true"
    ]
  }

  # ------------------------
  # File provisioners
  # ------------------------
  provisioner "file" {
    source      = "../../../../test-infra"
    destination = "/home/${var.ssh_username}/test-infra"
  }

  provisioner "file" {
    destination = "/home/${var.ssh_username}/timestamp.txt"
    content     = "${local.datestamp}"
  }

  provisioner "file" {
    destination = "/home/${var.ssh_username}/VERSION.txt"
    content     = <<-EOF
  Image Version: ${var.image_version}
  Built On: ${local.datestamp}
  EOF
  }

  # ------------------------
  # Shell provisioners for installation
  # ------------------------
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
  
  provisioner "shell" {
    inline = [
      "echo 'Waiting for Kubernetes API server...'",
      "for i in {1..30}; do kubectl get nodes && break || sleep 10; done",

      "echo 'Waiting for all nodes to be Ready...'",
      "for node in $(kubectl get nodes -o name); do kubectl wait --for=condition=Ready \"$node\" --timeout=300s; done",

      "echo 'Waiting for all pods to be Ready in all namespaces...'",
      "kubectl wait --for=condition=Ready pod --all --all-namespaces --timeout=300s",

      "for repo in mgmt mgmt-staging; do",
      "  echo \"Waiting for Repository '$repo' to become Ready...\"",
      "  kubectl wait --for=condition=Ready repository.config.porch.kpt.dev/\"$repo\" -n default --timeout=300s",
      "done"
    ]
  }
}
