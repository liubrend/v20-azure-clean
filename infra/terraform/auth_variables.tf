# Auth module inputs. Isolated from app/infra changes.

variable "github_repository" {
  description = "owner/repo allowed to assume the deploy identity via WIF."
  type        = string
  default     = "liubrend/v19-claudeTeamCCEY"
}

variable "github_ref" {
  description = "Git ref allowed to deploy (only this ref's Actions runs can assume the deploy SA)."
  type        = string
  default     = "refs/heads/main"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace running the backend."
  type        = string
  default     = "default"
}

variable "k8s_service_account" {
  description = "Kubernetes service account the backend pod runs as (Workload Identity)."
  type        = string
  default     = "app-backend"
}
