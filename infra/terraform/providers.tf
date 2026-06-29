provider "google" {
  project = var.project_id
  region  = var.region
}

# APIs the foundation needs. Auth/IAM-specific APIs (IAM Credentials, STS) are
# enabled by the isolated auth module (auth_*.tf, wif.tf).
resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}
