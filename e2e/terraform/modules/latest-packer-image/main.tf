terraform {
  required_providers {
    random = "~> 3.5"
    google = "~> 5.27"
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
  vm-name = "e2e-vm-${random_string.vm-name.result}"
}

output "self_link" {
  description = "Image self_link (used for boot_disk)"
  value       = local.resolved_image
}

output "name" {
  description = "Image name"
  value       = local.resolved_name
}

data "google_compute_image" "latest" {
  project     = var.project
  most_recent = true
  filter      = "name eq 'nephio-pre-baked-ubuntu-2204-lts.*'"
}

locals {
  resolved_image = data.google_compute_image.latest.self_link
  resolved_name  = data.google_compute_image.latest.name
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
      image = local.resolved_image
      size  = 200
    }
  }
  network_interface {
    network = "default"
    access_config {
    }
  }
  connection {
    host        = self.network_interface[0].access_config[0].nat_ip
    type        = "ssh"
    private_key = file(var.ssh_prv_key)
    user        = var.ansible_user
    agent       = false
  }
  provisioner "file" {
    source      = "../../../test-infra"
    destination = "/home/${var.ansible_user}/test-infra"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '🔍 Detecting OS and disk layout...'",

      "source /etc/os-release || true",
      "echo \"OS: $ID ($VERSION_ID)\"",

      "ROOT_PART=$(findmnt / -o SOURCE -n | sed 's/\\[.*\\]//')",  # Escaped brackets
      "DISK=$(echo $ROOT_PART | sed -E 's/[0-9]+$//')",  # Get the parent disk without the partition number
      "PART_NUM=$(echo $ROOT_PART | grep -o '[0-9]*$')",  # Extract the partition number
      "FS_TYPE=$(df -T / | tail -1 | awk '{print $2}')",  # Detect filesystem type

      "echo \"ROOT_PART: $ROOT_PART | DISK: $DISK | PART_NUM: $PART_NUM | FS_TYPE: $FS_TYPE\"",

      "echo '📦 Installing necessary packages...'",

      # Install necessary utilities for different distros
      "if [ -x $(command -v dnf) ]; then sudo dnf install -y cloud-utils-growpart; else sudo apt-get install -y cloud-guest-utils; fi",

      "echo '📈 Expanding partition...'",
      "if [ -x $(command -v growpart) ]; then sudo growpart $DISK $PART_NUM || echo '⚠️ growpart failed or unnecessary'; else echo '⚠️ growpart not available.'; fi",

      # Resize filesystem based on FS_TYPE
      "case $FS_TYPE in",
      "  btrfs)",
      "    echo '🔧 Resizing Btrfs filesystem...';",
      "    if ! command -v btrfs; then sudo dnf install -y btrfs-progs || true; fi;",
      "    sudo btrfs filesystem resize max / || echo '⚠️ Btrfs resize failed' ;;",

      "  ext4)",
      "    echo '🔧 Resizing ext4 filesystem...';",
      "    if ! command -v resize2fs; then sudo apt-get install -y e2fsprogs || true; fi;",
      "    sudo resize2fs $ROOT_PART || echo '⚠️ resize2fs failed' ;;",

      "  xfs)",
      "    echo '🔧 Resizing XFS filesystem...';",
      "    if ! command -v xfs_growfs; then sudo apt-get install -y xfsprogs || true; fi;",
      "    sudo xfs_growfs / || echo '⚠️ xfs_growfs failed' ;;",

      "  *)",
      "    echo \"❌ Unsupported filesystem type: $FS_TYPE\" ;;",
      "esac",

      "echo '✅ Final disk layout:'",
      "df -h /",
      "lsblk -f"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "! command -v dnf > /dev/null || sudo -- sh -c 'dnf update kernel-core -y; shutdown -r +1'"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for Kubernetes API server...'",
      "for i in {1..30}; do kubectl get nodes && break || sleep 10; done",

      "echo 'Waiting for all nodes to be Ready...'",
      "for node in $(kubectl get nodes -o name); do kubectl wait --for=condition=Ready \"$node\" --timeout=300s; done",

      "echo 'Waiting for all pods to be Ready in all namespaces...'",
      "kubectl wait --for=condition=Ready pod --all --all-namespaces --timeout=300s",

      "echo 'Waiting for sandbox repositories to become Ready...'",
      "bash -c 'for repo in mgmt mgmt-staging; do \
        echo Waiting for Repository \"$repo\" to become Ready...; \
        kubectl wait --for=condition=Ready repository.config.porch.kpt.dev/\"$repo\" -n default --timeout=300s; \
      done'"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/${var.ansible_user}/test-infra/e2e/",
      "chmod +x e2e.sh",
      "sudo -E FAIL_FAST=${var.nephio_e2e_fail_fast} MGMT_CLUSTER_TYPE=${var.nephio_mgmt_cluster_type} E2ETYPE=${var.nephio_e2e_type} NEPHIO_REPO_DIR=/home/${var.ansible_user}/test-infra NEPHIO_DEBUG=true NEPHIO_RUN_E2E=true NEPHIO_USER=${var.ansible_user} ./e2e.sh"
    ]
  }
}


variable "project" {
  description = "GCP project that will host CI instances"
  default     = "pure-faculty-367518"
  type        = string
}

variable "region" {
  description = "GCP region to deploy CI instances"
  default     = "europe-west9"
  type        = string
}

variable "zone" {
  description = "GCP zone to deploy CI instances"
  default     = "us-central1-c"
  type        = string
}

variable "instance" {
  description = "GCP flavor to be used by the CI instances"
  default     = "e2-standard-16"
  type        = string
}

variable "credentials" {
  description = "Credentials file to connect to GCP"
  default     = "/etc/satoken/satoken"
  type        = string
}

variable "ssh_prv_key" {
  description = "SSH private key for CI instance's connection"
  default     = "/etc/ssh-key/id_rsa"
  type        = string
}

variable "ssh_pub_key" {
  description = "SSH public key for CI instance's connection"
  default     = "/etc/ssh-key/id_rsa.pub"
  type        = string
}

variable "ansible_user" {
  description = "OS user used for Ansible connectivity"
  default     = "ubuntu"
  type        = string
}

variable "nephio_lab_nodes" {
  description = "The number of Lab instances to be created."
  default     = 0
  type        = number
}

variable "nephio_e2e_nodes" {
  description = "The number of End-to-End instances running per PR."
  default     = 1
  type        = number
}

variable "nephio_e2e_type" {
  description = "The Nephio End-to-End testing type"
  default     = "free5gc"
  type        = string
}

variable "nephio_e2e_fail_fast" {
  description = "The Nephio End-to-End testing failing behavior"
  default     = "false"
  type        = string
}

variable "nephio_mgmt_cluster_type" {
  description = "The Nephio management cluster type"
  default     = "kind"
  type        = string
}

variable "name_regex" {
  description = "Regex to match Packer image names"
  type        = string
}