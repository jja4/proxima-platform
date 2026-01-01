output "cluster_name" {
  description = "Workload cluster name"
  value       = google_container_cluster.workload.name
}

output "cluster_endpoint" {
  description = "Workload cluster endpoint"
  value       = google_container_cluster.workload.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Workload cluster CA certificate"
  value       = google_container_cluster.workload.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Workload cluster location"
  value       = google_container_cluster.workload.location
}
