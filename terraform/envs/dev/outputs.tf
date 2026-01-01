# =============================================================================
# MANAGEMENT CLUSTER OUTPUTS
# =============================================================================

output "management_cluster_name" {
  description = "Management cluster name"
  value       = module.management_cluster.cluster_name
}

output "management_cluster_endpoint" {
  description = "Management cluster endpoint"
  value       = module.management_cluster.cluster_endpoint
  sensitive   = true
}

output "management_cluster_location" {
  description = "Management cluster location"
  value       = module.management_cluster.cluster_location
}

output "management_connect_command" {
  description = "Command to connect to the management cluster"
  value       = "gcloud container clusters get-credentials ${module.management_cluster.cluster_name} --zone ${var.management_cluster_zone} --project ${var.project_id}"
}

# =============================================================================
# WORKLOAD CLUSTER OUTPUTS
# =============================================================================

output "workload_cluster_name" {
  description = "Workload cluster name"
  value       = module.workload_cluster.cluster_name
}

output "workload_cluster_endpoint" {
  description = "Workload cluster endpoint"
  value       = module.workload_cluster.cluster_endpoint
  sensitive   = true
}

output "workload_cluster_location" {
  description = "Workload cluster location"
  value       = module.workload_cluster.cluster_location
}

output "workload_connect_command" {
  description = "Command to connect to the workload cluster"
  value       = "gcloud container clusters get-credentials ${module.workload_cluster.cluster_name} --region ${var.region} --project ${var.project_id}"
}

# =============================================================================
# INFRASTRUCTURE OUTPUTS
# =============================================================================

output "artifact_registry" {
  description = "Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.ml_images.repository_id}"
}

output "gcs_bucket" {
  description = "GCS bucket for ML artifacts"
  value       = google_storage_bucket.ml_artifacts.name
}

output "workload_identity_sa" {
  description = "Workload Identity service account for jobs"
  value       = google_service_account.workload_identity.email
}

output "grafana_secret_name" {
  description = "Secret Manager secret name for Grafana password"
  value       = google_secret_manager_secret.grafana_password.secret_id
}

# =============================================================================
# ACCESS COMMANDS
# =============================================================================

output "setup_kubeconfigs" {
  description = "Commands to setup both cluster contexts"
  value       = <<-EOT
    # Connect to management cluster
    gcloud container clusters get-credentials ${module.management_cluster.cluster_name} --zone ${var.management_cluster_zone} --project ${var.project_id}
    
    # Connect to workload cluster
    gcloud container clusters get-credentials ${module.workload_cluster.cluster_name} --region ${var.region} --project ${var.project_id}
    
    # List contexts
    kubectl config get-contexts
  EOT
}