# Workload Identity Federation: GitHub Actions' OIDC token is exchanged for
# short-lived credentials that impersonate the deploy SA. Keyless — nothing
# long-lived is stored anywhere.

resource "google_project_service" "auth_services" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${var.name_prefix}-github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.auth_services]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"
  depends_on                         = [google_project_service.auth_services]

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Only Actions runs from this repository AND this ref (default: main) may exchange.
  # Forks, other repos, and PR/feature branches cannot assume the deploy identity.
  attribute_condition = "assertion.repository == \"${var.github_repository}\" && assertion.ref == \"${var.github_ref}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
    # Audience is left default: google-github-actions/auth requests the provider's
    # full resource URL as the audience, and GCP accepts that default. Do not set
    # allowed_audiences unless the deploy workflow passes a matching `audience`.
  }
}
