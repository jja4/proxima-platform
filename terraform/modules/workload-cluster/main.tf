# Workload Cluster Module
# GKE Autopilot cluster for Ray jobs with GPU auto-provisioning
# Scales from zero to handle bursty physics workloads

resource "google_container_cluster" "workload" {
  name     = "${var.project_name}-workload"
  location = var.region
  project  = var.project_id

  # Enable Autopilot mode
  enable_autopilot = true

  network    = var.network_name
  subnetwork = var.subnet_name

  # Autopilot requires Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster for security
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  # Autopilot manages logging/monitoring automatically
  # but we can specify components to enable
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  deletion_protection = false

  # Autopilot-specific configurations
  # Node auto-provisioning is automatic in Autopilot
  # GPU nodes will be provisioned on-demand based on pod requests

  resource_labels = {
    cluster-type = "workload"
    environment  = var.environment
    managed-by   = "terraform"
  }

  # Autopilot doesn't support node_config, node pools are managed automatically
}
