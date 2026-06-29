# Cloud SQL for PostgreSQL 16 — the system of record. Private IP only;
# reached from the cluster through the Cloud SQL Auth Proxy.
resource "google_sql_database_instance" "main" {
  name             = "${var.name_prefix}-pg"
  database_version = "POSTGRES_16"
  region           = var.region

  deletion_protection = var.deletion_protection
  depends_on          = [google_service_networking_connection.private_vpc]

  settings {
    tier              = var.db_tier
    edition           = var.db_edition
    availability_type = var.availability_type

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
  }
}

resource "google_sql_database" "app" {
  name     = var.db_name
  instance = google_sql_database_instance.main.name
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  password = random_password.db.result
}
