output "wif_provider" {
  value = module.gh_oidc.provider_name
  description = "Workload Identity Federation name"
}

output "wif_service_account" {
  value = google_service_account.packer_sa.email
  description = "Service account name"
}