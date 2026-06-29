output "vpc_network" {
  description = "VPC self link (the auth module and Cloud SQL connector reference it)."
  value       = google_compute_network.vpc.id
}

output "artifact_registry_repo" {
  description = "Artifact Registry repository id for the backend image."
  value       = google_artifact_registry_repository.backend.repository_id
}

output "cloudsql_connection_name" {
  description = "Cloud SQL instance connection name (project:region:instance)."
  value       = google_sql_database_instance.main.connection_name
}

output "database_url_secret_id" {
  description = "Secret Manager secret holding DATABASE_URL."
  value       = google_secret_manager_secret.database_url.secret_id
}

output "gke_cluster_name" {
  description = "GKE Autopilot cluster name."
  value       = google_container_cluster.main.name
}
