variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "ml-platform"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west3"
}

variable "cluster_location" {
  description = "Optional zone for the GKE cluster/node pools"
  type        = string
  default     = ""
}

variable "terraform_user_list" {
  description = "Principals (user:, serviceAccount:, group:) that run Terraform and need to impersonate the GKE node SA"
  type        = list(string)
  default     = []
}

variable "enable_gpu_pool" {
  description = "Enable GPU node pool"
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  description = "Initial Grafana admin password (will be stored in Secret Manager)"
  type        = string
  default     = "changeme-in-production"
  sensitive   = true
}