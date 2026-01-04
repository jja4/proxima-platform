# Main Terraform configuration for dev environment
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  backend "gcs" {
    bucket = "SET_YOUR_BUCKET_NAME"  # This will be replaced during 'terraform init -backend-config="bucket=${PROJECT_ID}-terraform-state"'
    prefix = "dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

# Service Account for GKE nodes
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.project_name}-gke-sa"
  display_name = "GKE Node Service Account"
}

resource "google_project_iam_member" "gke_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/storage.objectAdmin",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_service_account_iam_member" "gke_nodes_impersonators" {
  for_each           = toset(var.terraform_user_list)
  service_account_id = google_service_account.gke_nodes.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_id     = var.project_id
  project_name   = var.project_name
  region         = var.region
  subnet_cidr    = "10.0.0.0/20"
  pods_cidr      = "10.4.0.0/14"
  services_cidr  = "10.8.0.0/20"

  depends_on = [google_project_service.required_apis]
}

# =============================================================================
# DUAL CLUSTER SETUP: Management + Workload
# =============================================================================

# Management Cluster - Small, stable cluster for platform tools
# Runs: Backstage, ArgoCD, Crossplane, Prometheus
module "management_cluster" {
  source = "../../modules/management-cluster"

  project_id            = var.project_id
  project_name          = var.project_name
  location              = var.management_cluster_zone
  environment           = "dev"
  network_name          = module.vpc.network_name
  subnet_name           = module.vpc.subnet_name
  pods_range_name       = module.vpc.pods_range_name
  services_range_name   = module.vpc.services_range_name
  service_account_email = google_service_account.gke_nodes.email
  
  machine_type       = "e2-medium"  # 2 vCPU, 4GB RAM (~$25/mo) - Required for system pods + ArgoCD/Backstage
  initial_node_count = 1
  node_count         = 5

  depends_on = [
    module.vpc,
    google_service_account_iam_member.gke_nodes_impersonators
  ]
}

# Workload Cluster - GKE Autopilot for Ray jobs with GPU auto-provisioning
# Scales from zero, provisions T4 nodes on-demand
module "workload_cluster" {
  source = "../../modules/workload-cluster"

  project_id          = var.project_id
  project_name        = var.project_name
  region              = var.region
  environment         = "dev"
  network_name        = module.vpc.network_name
  subnet_name         = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name

  depends_on = [module.vpc]
}

# =============================================================================
# STORAGE AND ARTIFACT REGISTRY
# =============================================================================

# Artifact Registry
resource "google_artifact_registry_repository" "ml_images" {
  location      = var.region
  repository_id = var.project_name
  format        = "DOCKER"
  description   = "ML training container images"

  depends_on = [google_project_service.required_apis]
}

# GCS Bucket for artifacts
resource "google_storage_bucket" "ml_artifacts" {
  name          = "${var.project_id}-ml-artifacts"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Configure kubectl
data "google_client_config" "default" {}

# Use try() to allow terraform plan to succeed before the cluster exists.
# The kubernetes/helm providers will receive dummy values during initial plan,
# but all k8s resources have depends_on = [module.management_cluster] so they won't be created
# until the cluster is ready.
provider "kubernetes" {
  host                   = try("https://${module.management_cluster.cluster_endpoint}", null)
  token                  = try(data.google_client_config.default.access_token, null)
  cluster_ca_certificate = try(base64decode(module.management_cluster.cluster_ca_certificate), null)
}

provider "helm" {
  kubernetes {
    host                   = try("https://${module.management_cluster.cluster_endpoint}", null)
    token                  = try(data.google_client_config.default.access_token, null)
    cluster_ca_certificate = try(base64decode(module.management_cluster.cluster_ca_certificate), null)
  }
}

provider "kubectl" {
  host                   = try("https://${module.management_cluster.cluster_endpoint}", null)
  token                  = try(data.google_client_config.default.access_token, null)
  cluster_ca_certificate = try(base64decode(module.management_cluster.cluster_ca_certificate), null)
  load_config_file       = false
}

# =============================================================================
# GCP SERVICE ACCOUNTS FOR WORKLOAD IDENTITY
# =============================================================================

# Service Account for External Secrets Operator (ESO) on management cluster
resource "google_service_account" "eso_workload_identity" {
  account_id   = "${var.project_name}-eso-sa"
  display_name = "External Secrets Operator Service Account"
}

# Grant Secret Manager access to ESO
resource "google_project_iam_member" "eso_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso_workload_identity.email}"
}

# Bind Kubernetes SA (created by ESO Helm chart) to GCP SA via Workload Identity
resource "google_service_account_iam_member" "eso_workload_identity_binding" {
  service_account_id = google_service_account.eso_workload_identity.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

# Dedicated service account for workload identity on the workload cluster
resource "google_service_account" "workload_identity" {
  account_id   = "${var.project_name}-workload-sa"
  display_name = "Workload Identity Service Account for Jobs"
}

# Grant GCS access to workload identity SA
resource "google_project_iam_member" "workload_identity_gcs" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.workload_identity.email}"
}

# Bind Kubernetes SA to GCP SA via Workload Identity
# (Kubernetes SA will be created in workload cluster via ArgoCD)
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.workload_identity.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[jobs/job-runner]"
}

# =============================================================================
# SECRETS MANAGEMENT (GCP Secret Manager)
# =============================================================================

# Enable Secret Manager API
resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Create a secret for Grafana admin password
resource "google_secret_manager_secret" "grafana_password" {
  secret_id = "${var.project_name}-grafana-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# Initial secret version (should be rotated after first deployment)
resource "google_secret_manager_secret_version" "grafana_password" {
  secret      = google_secret_manager_secret.grafana_password.id
  secret_data = var.grafana_admin_password

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# Grant workload identity access to secrets
resource "google_secret_manager_secret_iam_member" "workload_secret_access" {
  secret_id = google_secret_manager_secret.grafana_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.workload_identity.email}"
}
