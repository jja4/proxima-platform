# Terraform Test Configuration for ML Platform (Dual Cluster Architecture)
# Run with: terraform test from the terraform/ directory

# =============================================================================
# Global Variables for Testing
# =============================================================================

variables {
  project_id              = "test-project-id"
  project_name            = "ml-platform"
  region                  = "europe-west3"
  management_cluster_zone  = "europe-west3-a"
  environment             = "dev"
  network_name            = "ml-platform-vpc"
  subnet_name             = "ml-platform-gke-subnet"
  pods_range_name         = "pods"
  services_range_name     = "services"
  service_account_email   = "test-sa@test-project-id.iam.gserviceaccount.com"
  grafana_admin_password  = "test-password"
  git_repo_url            = "https://github.com/test-org/test-repo.git"
  terraform_user_list     = ["user:test@example.com"]
}

# =============================================================================
# Module: VPC Tests
# =============================================================================

run "vpc_network_creation" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    subnet_cidr   = "10.0.0.0/20"
    pods_cidr     = "10.4.0.0/14"
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

# =============================================================================
# Module: Management Cluster Tests
# =============================================================================

run "management_cluster_configuration" {
  command = plan

  module {
    source = "./modules/management-cluster"
  }

  variables {
    location     = "europe-west3-a" # Module uses 'location' instead of 'management_cluster_zone'
    machine_type = "e2-medium"
  }

  assert {
    condition     = google_container_cluster.management.name == "ml-platform-management"
    error_message = "Management cluster name should be 'ml-platform-management'"
  }

  assert {
    condition     = google_container_cluster.management.remove_default_node_pool == true
    error_message = "Default node pool should be removed in management cluster"
  }

  assert {
    condition     = google_container_node_pool.management_nodes.node_config[0].machine_type == "e2-medium"
    error_message = "Management node machine type should be e2-medium"
  }
}

# =============================================================================
# Module: Workload Cluster Tests (Autopilot)
# =============================================================================

run "workload_cluster_configuration" {
  command = plan

  module {
    source = "./modules/workload-cluster"
  }

  assert {
    condition     = google_container_cluster.workload.name == "ml-platform-workload"
    error_message = "Workload cluster name should be 'ml-platform-workload'"
  }

  assert {
    condition     = google_container_cluster.workload.enable_autopilot == true
    error_message = "Workload cluster should have Autopilot enabled"
  }

  assert {
    condition     = google_container_cluster.workload.location == "europe-west3"
    error_message = "Workload cluster should be regional (europe-west3)"
  }
}

# =============================================================================
# Integration Tests (Validate full dev environment)
# =============================================================================

run "dev_environment_validates" {
  command = plan

  module {
    source = "./envs/dev"
  }

  # Inherits all global variables automatically

  assert {
    condition     = module.management_cluster.cluster_name == "ml-platform-management"
    error_message = "Dev environment should correctly provision the management cluster"
  }

  assert {
    condition     = module.workload_cluster.cluster_name == "ml-platform-workload"
    error_message = "Dev environment should correctly provision the workload cluster"
  }

  assert {
    condition     = google_artifact_registry_repository.ml_images.repository_id == "ml-platform"
    error_message = "Dev environment should correctly provision the artifact registry"
  }
}
