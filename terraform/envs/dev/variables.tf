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

variable "management_cluster_zone" {
  description = "Zone for the management cluster (e.g., europe-west3-a)"
  type        = string
  default     = "europe-west3-a"
}


variable "terraform_user_list" {
  description = "Principals (user:, serviceAccount:, group:) that run Terraform and need to impersonate the GKE node SA"
  type        = list(string)
  default     = []
}

variable "grafana_admin_password" {
  description = "Initial Grafana admin password (will be stored in Secret Manager)"
  type        = string
  default     = "changeme-in-production"
  sensitive   = true
}

variable "git_repo_url" {
  description = "Git repository URL for GitOps (ArgoCD source)"
  type        = string
  default     = "https://github.com/YOUR_ORG/proxima-platform.git"
}

variable "git_branch" {
  description = "Git branch for GitOps and Backstage template references"
  type        = string
  default     = "main"
}