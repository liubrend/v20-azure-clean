variable "project_id" {
  description = "Target GCP project id."
  type        = string
}

variable "region" {
  description = "Primary region for regional resources."
  type        = string
  default     = "europe-west1"
}

variable "name_prefix" {
  description = "Prefix applied to resource names."
  type        = string
  default     = "app"
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-custom-1-3840"
}

variable "availability_type" {
  description = "Cloud SQL availability: ZONAL (MVP) or REGIONAL (HA)."
  type        = string
  default     = "ZONAL"
}

variable "db_edition" {
  description = "Cloud SQL edition. ENTERPRISE supports db-custom-* tiers; ENTERPRISE_PLUS requires db-perf-optimized-*."
  type        = string
  default     = "ENTERPRISE"
}

variable "db_name" {
  description = "Application database name."
  type        = string
  default     = "app"
}

variable "db_user" {
  description = "Application database user."
  type        = string
  default     = "app"
}

variable "deletion_protection" {
  description = "Guard stateful resources (Cloud SQL) against terraform destroy."
  type        = bool
  default     = true
}
