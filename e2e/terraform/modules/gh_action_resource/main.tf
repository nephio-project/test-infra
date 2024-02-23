# Create service account for Github Actions
data "google_project" "main" {
  project_id = var.project_id
}

resource "google_service_account" "packer_sa" {
  account_id = "github-action-packer-sa"
  display_name = "Service account for GitHub Actions"
}

resource "google_project_iam_member" "packer_sa_iam_member" {
  project = var.project_id
  count = length(var.packer_sa_iam_roles_list)
  role = var.packer_sa_iam_roles_list[count.index]
  member = "serviceAccount:${google_service_account.packer_sa.email}"
}

# Create Workload Iddentity Fedetation on GCP for Github actions authentication
module "gh_oidc" {
  source = "terraform-google-modules/github-actions-runners/google//modules/gh-oidc"
  version = "3.1.1"
  
  project_id = var.project_id
  pool_id = var.wif_pool_id
  provider_id = "github"
  sa_mapping = {
    "packer-sa" = {
      sa_name   = google_service_account.packer_sa.id
      attribute = format("attribute.repository/%s/%s", var.github_org, var.github_repo)
    }
  }
}