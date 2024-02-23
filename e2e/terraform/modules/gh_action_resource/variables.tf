variable "project_id" {
  description = "GCP project ID"
  default     = "pure-faculty-367518"
  type        = string
}

variable "region" {
  description = "Region to deploy GCP resources"
  type        = string
  default     = "europe-west1"
}

variable "wif_pool_id" {
  description = "Workload Identity Federation pool ID"
  default     = "nephio_wif_pool_id"
  type        = string
}

variable "packer_sa_iam_roles_list" {
  description = "List of IAM roles to be assigned to Packer WIF service account"
  type        = list(string)
  default = [
    "roles/compute.instanceAdmin.v1",
    "roles/iam.serviceAccountUser",
  ]
}

variable "github_org" {
  description = "GitHub repo owner name"
  default     = "nephio-project"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name"
  default     = "test-infra"
  type        = string
}
