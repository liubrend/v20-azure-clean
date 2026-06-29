# DATABASE_URL lives in Secret Manager and is injected into the pod at runtime —
# never hardcoded, never in git (CLAUDE.md invariant). The host is 127.0.0.1:5432,
# the in-pod Cloud SQL Auth Proxy sidecar.
resource "google_secret_manager_secret" "database_url" {
  secret_id  = "${var.name_prefix}-database-url"
  depends_on = [google_project_service.services]

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  secret_data = format(
    "postgresql://%s:%s@127.0.0.1:5432/%s",
    var.db_user,
    random_password.db.result,
    var.db_name,
  )
}
