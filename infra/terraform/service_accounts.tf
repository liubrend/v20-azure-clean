# Two identities: one CI impersonates (deploy), one the backend pod runs as (runtime).
# Neither has a key — deploy is reached keylessly via WIF, runtime via GKE Workload
# Identity. No service-account keys are ever created (CLAUDE.md: secrets from env).

resource "google_service_account" "deploy" {
  account_id   = "${var.name_prefix}-deploy"
  display_name = "v19-GCP-clean-teamsEnabled CI deploy (Workload Identity Federation target)"
}

resource "google_service_account" "runtime" {
  account_id   = "${var.name_prefix}-runtime"
  display_name = "v19-GCP-clean-teamsEnabled backend workload (GKE Workload Identity)"
}
