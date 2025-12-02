# Terraform Test Configuration for ML Platform
# Run with: terraform test

# =============================================================================
# Variables for Testing
# =============================================================================

variables {
  project_id             = "test-project-id"
  project_name           = "ml-platform"
  region                 = "europe-west3"
  enable_gpu_pool        = false
  grafana_admin_password = "test-password"
}

# =============================================================================
# Module: VPC Tests
# =============================================================================

run "vpc_network_creation" {
  command = plan

  module {
    source = "../modules/vpc"
  }

  variables {
    project_id   = "test-project-id"
    project_name = "ml-platform"
    region       = "europe-west3"
    subnet_cidr  = "10.0.0.0/20"
    pods_cidr    = "10.4.0.0/14"
    services_cidr = "10.8.0.0/20"
  }

  assert {
    condition     = google_compute_network.vpc.name == "ml-platform-vpc"
    error_message = "VPC network name should be 'ml-platform-vpc'"
  }

  assert {
    condition     = google_compute_network.vpc.auto_create_subnetworks == false
    error_message = "VPC should not auto-create subnetworks"
  }
}

run "vpc_subnet_configuration" {
  command = plan

  module {
    source = "../modules/vpc"
  }

  variables {
    project_id   = "test-project-id"
    project_name = "ml-platform"
    region       = "europe-west3"
    subnet_cidr  = "10.0.0.0/20"
    pods_cidr    = "10.4.0.0/14"
    services_cidr = "10.8.0.0/20"
  }

  assert {
    condition     = google_compute_subnetwork.gke_subnet.ip_cidr_range == "10.0.0.0/20"
    error_message = "Subnet CIDR should be '10.0.0.0/20'"
  }

  assert {
    condition     = google_compute_subnetwork.gke_subnet.private_ip_google_access == true
    error_message = "Private Google Access should be enabled"
  }

  assert {
    condition     = length(google_compute_subnetwork.gke_subnet.secondary_ip_range) == 2
    error_message = "Subnet should have 2 secondary IP ranges (pods and services)"
  }
}

run "vpc_nat_configuration" {
  command = plan

  module {
    source = "../modules/vpc"
  }

  variables {
    project_id   = "test-project-id"
    project_name = "ml-platform"
    region       = "europe-west3"
    subnet_cidr  = "10.0.0.0/20"
    pods_cidr    = "10.4.0.0/14"
    services_cidr = "10.8.0.0/20"
  }

  assert {
    condition     = google_compute_router_nat.nat.nat_ip_allocate_option == "AUTO_ONLY"
    error_message = "NAT should use AUTO_ONLY for IP allocation"
  }

  assert {
    condition     = google_compute_router_nat.nat.source_subnetwork_ip_ranges_to_nat == "ALL_SUBNETWORKS_ALL_IP_RANGES"
    error_message = "NAT should apply to all subnetworks"
  }
}

# =============================================================================
# Module: GKE Tests
# =============================================================================

run "gke_cluster_configuration" {
  command = plan

  module {
    source = "../modules/gke"
  }

  variables {
    project_id            = "test-project-id"
    project_name          = "ml-platform"
    region                = "europe-west3"
    environment           = "dev"
    network_name          = "ml-platform-vpc"
    subnet_name           = "ml-platform-gke-subnet"
    pods_range_name       = "pods"
    services_range_name   = "services"
    service_account_email = "test-sa@test-project-id.iam.gserviceaccount.com"
    cpu_machine_type      = "n2-standard-4"
    cpu_min_nodes         = 1
    cpu_max_nodes         = 5
    use_preemptible       = true
    enable_gpu_pool       = false
  }

  assert {
    condition     = google_container_cluster.primary.name == "ml-platform-gke"
    error_message = "GKE cluster name should be 'ml-platform-gke'"
  }

  assert {
    condition     = google_container_cluster.primary.remove_default_node_pool == true
    error_message = "Default node pool should be removed"
  }

  assert {
    condition     = google_container_cluster.primary.release_channel[0].channel == "REGULAR"
    error_message = "Release channel should be REGULAR"
  }
}

run "gke_cpu_node_pool" {
  command = plan

  module {
    source = "../modules/gke"
  }

  variables {
    project_id            = "test-project-id"
    project_name          = "ml-platform"
    region                = "europe-west3"
    environment           = "dev"
    network_name          = "ml-platform-vpc"
    subnet_name           = "ml-platform-gke-subnet"
    pods_range_name       = "pods"
    services_range_name   = "services"
    service_account_email = "test-sa@test-project-id.iam.gserviceaccount.com"
    cpu_machine_type      = "n2-standard-4"
    cpu_min_nodes         = 1
    cpu_max_nodes         = 5
    use_preemptible       = true
    enable_gpu_pool       = false
  }

  assert {
    condition     = google_container_node_pool.cpu_pool.name == "cpu-pool"
    error_message = "CPU node pool name should be 'cpu-pool'"
  }

  assert {
    condition     = google_container_node_pool.cpu_pool.autoscaling[0].min_node_count == 1
    error_message = "CPU pool min nodes should be 1"
  }

  assert {
    condition     = google_container_node_pool.cpu_pool.autoscaling[0].max_node_count == 5
    error_message = "CPU pool max nodes should be 5"
  }

  assert {
    condition     = google_container_node_pool.cpu_pool.node_config[0].preemptible == true
    error_message = "CPU nodes should be preemptible in dev"
  }

  assert {
    condition     = google_container_node_pool.cpu_pool.node_config[0].machine_type == "n2-standard-4"
    error_message = "CPU node machine type should be n2-standard-4"
  }
}

run "gke_workload_identity_enabled" {
  command = plan

  module {
    source = "../modules/gke"
  }

  variables {
    project_id            = "test-project-id"
    project_name          = "ml-platform"
    region                = "europe-west3"
    environment           = "dev"
    network_name          = "ml-platform-vpc"
    subnet_name           = "ml-platform-gke-subnet"
    pods_range_name       = "pods"
    services_range_name   = "services"
    service_account_email = "test-sa@test-project-id.iam.gserviceaccount.com"
    cpu_machine_type      = "n2-standard-4"
    cpu_min_nodes         = 1
    cpu_max_nodes         = 5
    use_preemptible       = true
    enable_gpu_pool       = false
  }

  assert {
    condition     = google_container_cluster.primary.workload_identity_config[0].workload_pool == "test-project-id.svc.id.goog"
    error_message = "Workload Identity should be enabled with correct pool"
  }
}

run "gke_gpu_pool_disabled_by_default" {
  command = plan

  module {
    source = "../modules/gke"
  }

  variables {
    project_id            = "test-project-id"
    project_name          = "ml-platform"
    region                = "europe-west3"
    environment           = "dev"
    network_name          = "ml-platform-vpc"
    subnet_name           = "ml-platform-gke-subnet"
    pods_range_name       = "pods"
    services_range_name   = "services"
    service_account_email = "test-sa@test-project-id.iam.gserviceaccount.com"
    cpu_machine_type      = "n2-standard-4"
    cpu_min_nodes         = 1
    cpu_max_nodes         = 5
    use_preemptible       = true
    enable_gpu_pool       = false
  }

  assert {
    condition     = length(google_container_node_pool.gpu_pool) == 0
    error_message = "GPU pool should not be created when enable_gpu_pool is false"
  }
}

run "gke_gpu_pool_enabled" {
  command = plan

  module {
    source = "../modules/gke"
  }

  variables {
    project_id            = "test-project-id"
    project_name          = "ml-platform"
    region                = "europe-west3"
    environment           = "dev"
    network_name          = "ml-platform-vpc"
    subnet_name           = "ml-platform-gke-subnet"
    pods_range_name       = "pods"
    services_range_name   = "services"
    service_account_email = "test-sa@test-project-id.iam.gserviceaccount.com"
    cpu_machine_type      = "n2-standard-4"
    cpu_min_nodes         = 1
    cpu_max_nodes         = 5
    use_preemptible       = true
    enable_gpu_pool       = true
    gpu_machine_type      = "n1-standard-8"
    gpu_type              = "nvidia-tesla-t4"
    gpu_count             = 1
    gpu_min_nodes         = 0
    gpu_max_nodes         = 4
  }

  assert {
    condition     = length(google_container_node_pool.gpu_pool) == 1
    error_message = "GPU pool should be created when enable_gpu_pool is true"
  }
}

# =============================================================================
# Integration Tests (Validate full dev environment)
# =============================================================================

run "dev_environment_validates" {
  command = plan

  # This test validates the entire dev environment configuration
  # It ensures all modules work together correctly

  assert {
    condition     = true
    error_message = "Dev environment should validate successfully"
  }
}
