# GKE Autopilot runs the containerized FastAPI backend. VPC-native,
# on the same network as the Cloud SQL private peering.
resource "google_container_cluster" "main" {
  name     = "${var.name_prefix}-gke"
  location = var.region

  enable_autopilot    = true
  network             = google_compute_network.vpc.id
  deletion_protection = var.deletion_protection

  # Order the cluster after the Cloud SQL private-services peering so workloads can
  # reach the database's private IP (via the in-pod Auth Proxy) as soon as they roll.
  depends_on = [
    google_project_service.services,
    google_service_networking_connection.private_vpc,
  ]

  # Required for VPC-native (Autopilot); empty block lets GKE manage the ranges.
  ip_allocation_policy {}
}
