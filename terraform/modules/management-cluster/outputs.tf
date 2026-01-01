output "cluster_name" {
  description = "Management cluster name"
  value       = google_container_cluster.management.name
}

output "cluster_endpoint" {
  description = "Management cluster endpoint"
  value       = google_container_cluster.management.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Management cluster CA certificate"
  value       = google_container_cluster.management.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Management cluster location"
  value       = google_container_cluster.management.location
}
