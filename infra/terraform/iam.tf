locals {
  # Repository-wide principalSet is safe: the provider's attribute_condition already
  # requires assertion.ref == var.github_ref, so only this repo's main-branch Actions
  # runs can mint a token at all. The condition is the ref boundary (standard WIF
  # pattern; avoids a custom-attribute value-format mismatch).
  github_principal = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"

  deploy_sa_member  = "serviceAccount:${google_service_account.deploy.email}"
  runtime_sa_member = "serviceAccount:${google_service_account.runtime.email}"

  # Least-privilege project roles for the CI deploy identity.
  deploy_roles = [
    "roles/artifactregistry.writer", # push the backend image
    "roles/container.developer",     # roll out to GKE
    "roles/cloudsql.client",         # run migrations via the Auth Proxy
    "roles/firebasehosting.admin",   # deploy the frontend
  ]
}

# --- CI may assume the deploy SA (keyless, via WIF) ------------------------------
resource "google_service_account_iam_member" "deploy_via_wif" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.github_principal
}

# --- Deploy SA permissions -------------------------------------------------------
resource "google_project_iam_member" "deploy" {
  for_each = toset(local.deploy_roles)
  project  = var.project_id
  role     = each.value
  member   = local.deploy_sa_member
}

# Deploy SA may act as the runtime SA when rolling workloads that run as it.
resource "google_service_account_iam_member" "deploy_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = local.deploy_sa_member
}

# Deploy SA reads DATABASE_URL for the migrate step (secret-level, not project-wide).
resource "google_secret_manager_secret_iam_member" "deploy_database_url" {
  secret_id = google_secret_manager_secret.database_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.deploy_sa_member
}

# --- Runtime SA permissions ------------------------------------------------------
resource "google_project_iam_member" "runtime_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = local.runtime_sa_member
}

resource "google_secret_manager_secret_iam_member" "runtime_database_url" {
  secret_id = google_secret_manager_secret.database_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.runtime_sa_member
}

# GKE Workload Identity: the in-cluster k8s SA acts as the runtime SA. The
# ${project}.svc.id.goog identity pool only exists once a Workload-Identity cluster
# is created, so this binding must wait for the cluster.
resource "google_service_account_iam_member" "runtime_workload_identity" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
  depends_on         = [google_container_cluster.main]
}
