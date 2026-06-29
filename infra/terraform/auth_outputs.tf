# Set these as GitHub repo variables so the deploy workflows resolve (non-secret).

output "wif_provider" {
  description = "Full WIF provider resource name → GitHub var WIF_PROVIDER."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deploy_service_account_email" {
  description = "CI deploy SA → GitHub var DEPLOY_SA_EMAIL."
  value       = google_service_account.deploy.email
}

output "runtime_service_account_email" {
  description = "Backend workload SA → annotate the k8s ServiceAccount with this."
  value       = google_service_account.runtime.email
}
