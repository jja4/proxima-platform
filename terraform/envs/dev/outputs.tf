output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "artifact_registry" {
  description = "Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.ml_images.repository_id}"
}

output "gcs_bucket" {
  description = "GCS bucket for ML artifacts"
  value       = google_storage_bucket.ml_artifacts.name
}

output "connect_command" {
  description = "Command to connect to the cluster"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "workload_identity_sa" {
  description = "Workload Identity service account for jobs"
  value       = google_service_account.workload_identity.email
}

output "grafana_secret_name" {
  description = "Secret Manager secret name for Grafana password"
  value       = google_secret_manager_secret.grafana_password.secret_id
}

output "ray_dashboard_command" {
  description = "Command to port-forward Ray dashboard"
  value       = "kubectl port-forward -n ray-system svc/ray-cluster-head-svc 8265:8265"
}

output "grafana_dashboard_command" {
  description = "Command to port-forward Grafana dashboard"
  value       = "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
}