# Management Cluster Module
# Small, stable cluster for Backstage, ArgoCD, Crossplane, Prometheus
# Standard GKE mode with minimal e2-micro nodes

resource "google_container_cluster" "management" {
  name     = "${var.project_name}-management"
  location = var.location
  project  = var.project_id

  network    = var.network_name
  subnetwork = var.subnet_name

  # We use a separate node pool resource for better manageability
  remove_default_node_pool = true
  initial_node_count       = var.initial_node_count

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

  # Minimal addons for management plane
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  # Minimal logging for cost savings
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  # Minimal monitoring for cost savings
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  deletion_protection = false

  resource_labels = {
    cluster-type = "management"
    environment  = var.environment
    managed-by   = "terraform"
  }
}

# Separate Node Pool for the Management Cluster
resource "google_container_node_pool" "management_nodes" {
  name       = "management-pool"
  location   = var.location
  cluster    = google_container_cluster.management.name
  project    = var.project_id
  node_count = var.node_count

  node_config {
    machine_type    = var.machine_type
    service_account = var.service_account_email
    disk_size_gb    = 20
    disk_type       = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      cluster-type = "management"
      environment  = var.environment
      managed-by   = "terraform"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
