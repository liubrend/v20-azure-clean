# Docker repository for the backend image.
resource "google_artifact_registry_repository" "backend" {
  location      = var.region
  repository_id = "${var.name_prefix}-backend"
  description   = "v19-GCP-clean-teamsEnabled FastAPI backend images"
  format        = "DOCKER"
  depends_on    = [google_project_service.services]
}
