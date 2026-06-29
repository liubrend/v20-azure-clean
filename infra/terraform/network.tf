# VPC plus Private Services Access, so Cloud SQL gets a private IP reachable from
# the GKE workloads (the Cloud SQL Auth Proxy connects over this peering).
resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = true
  depends_on              = [google_project_service.services]
}

resource "google_compute_global_address" "private_services" {
  name          = "${var.name_prefix}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}
