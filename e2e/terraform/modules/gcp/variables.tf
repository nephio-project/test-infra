variable "project" {
  description = "GCP project that will host CI instances"
  default     = "pure-faculty-367518"
  type        = string
}

variable "region" {
  description = "GCP region to deploy CI instances"
  default     = "us-central1"
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

variable "vmimage" {
  description = "OS image to be used for the creation of CI instances"
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
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
