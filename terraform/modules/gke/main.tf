# GKE Cluster Module
resource "google_container_cluster" "primary" {
  name     = "${var.project_name}-gke"
  location = var.region
  project  = var.project_id

  network    = var.network_name
  subnetwork = var.subnet_name

  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

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

  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_container_node_pool" "cpu_pool" {
  name     = "cpu-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = var.cpu_min_nodes
    max_node_count = var.cpu_max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.cpu_machine_type
    preemptible     = var.use_preemptible
    service_account = var.service_account_email
    disk_size_gb    = 30          # Minimum viable for GKE
    disk_type       = "pd-standard"  # Cheapest disk type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      workload    = "cpu"
      environment = var.environment
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

resource "google_container_node_pool" "gpu_pool" {
  count = var.enable_gpu_pool ? 1 : 0

  name     = "gpu-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = var.gpu_min_nodes
    max_node_count = var.gpu_max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.gpu_machine_type
    service_account = var.service_account_email
    disk_size_gb    = 200
    disk_type       = "pd-ssd"

    guest_accelerator {
      type  = var.gpu_type
      count = var.gpu_count
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth-platform"
    ]

    labels = {
      workload    = "gpu"
      environment = var.environment
    }

    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}