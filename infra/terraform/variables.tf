variable "subscription_id" {
  description = "Target Azure subscription id."
  type        = string
}

variable "location" {
  description = "Primary Azure region for regional resources."
  type        = string
  default     = "westeurope"
}

variable "name_prefix" {
  description = "Prefix applied to resource names. Keep short/lowercase — some Azure names are length/charset constrained."
  type        = string
  default     = "v20az"
}

variable "sql_admin_login" {
  description = "Azure SQL server administrator login."
  type        = string
  default     = "sqladmin"
}

variable "db_name" {
  description = "Application database name."
  type        = string
  default     = "app"
}

variable "sql_sku" {
  description = "Azure SQL Database SKU (e.g. Basic, S0, GP_S_Gen5_1)."
  type        = string
  default     = "S0"
}

variable "blob_container" {
  description = "Blob container for item attachments."
  type        = string
  default     = "attachments"
}

variable "github_repository" {
  description = "owner/repo allowed to assume the deploy identity via GitHub OIDC."
  type        = string
  default     = "liubrend/v20-Azure-clean-teamsEnabled"
}

variable "github_ref" {
  description = "Git ref allowed to deploy (only this ref's Actions runs can assume the deploy identity)."
  type        = string
  default     = "refs/heads/main"
}

variable "gateway_image" {
  description = "api-gateway image. Placeholder until the deploy workflow pushes the real tag."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "sample_service_image" {
  description = "sample-service image. Placeholder until the deploy workflow pushes the real tag."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}
