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
  }

  backend "gcs" {
    bucket = "SET_YOUR_BUCKET_NAME"  # Update this
    prefix = "constellaration-platform/dev"
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

# GKE Module
module "gke" {
  source = "../../modules/gke"

  project_id            = var.project_id
  project_name          = var.project_name
  region                = var.region
  environment           = "dev"
  network_name          = module.vpc.network_name
  subnet_name           = module.vpc.subnet_name
  pods_range_name       = module.vpc.pods_range_name
  services_range_name   = module.vpc.services_range_name
  service_account_email = google_service_account.gke_nodes.email

  # Dev configuration
  cpu_machine_type  = "n2-standard-4"
  cpu_min_nodes     = 1
  cpu_max_nodes     = 5
  use_preemptible   = true
  enable_gpu_pool   = false

  depends_on = [module.vpc]
}

# Artifact Registry
resource "google_artifact_registry_repository" "ml_images" {
  location      = var.region
  repository_id = "${var.project_name}-ml"
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

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}

# Create namespaces
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(["ray-system", "jobs", "monitoring"])

  metadata {
    name = each.key
    labels = {
      managed-by = "terraform"
    }
  }

  depends_on = [module.gke]
}

# Install KubeRay Operator
resource "helm_release" "kuberay_operator" {
  name       = "kuberay-operator"
  repository = "https://ray-project.github.io/kuberay-helm/"
  chart      = "kuberay-operator"
  version    = "1.1.0"
  namespace  = kubernetes_namespace.namespaces["ray-system"].metadata[0].name

  set {
    name  = "image.tag"
    value = "v1.1.0"
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# Install Prometheus
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.0.0"
  namespace  = kubernetes_namespace.namespaces["monitoring"].metadata[0].name

  values = [templatefile("${path.module}/prometheus-values.yaml", {})]

  depends_on = [kubernetes_namespace.namespaces]
}

# =============================================================================
# RBAC Configuration
# =============================================================================

# Service Account for job runners
resource "kubernetes_service_account" "job_runner" {
  metadata {
    name      = "job-runner"
    namespace = kubernetes_namespace.namespaces["jobs"].metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.workload_identity.email
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# Role for job runners
resource "kubernetes_role" "job_runner" {
  metadata {
    name      = "job-runner-role"
    namespace = kubernetes_namespace.namespaces["jobs"].metadata[0].name
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# RoleBinding for job runners
resource "kubernetes_role_binding" "job_runner" {
  metadata {
    name      = "job-runner-binding"
    namespace = kubernetes_namespace.namespaces["jobs"].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.job_runner.metadata[0].name
    namespace = kubernetes_namespace.namespaces["jobs"].metadata[0].name
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role.job_runner.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

# =============================================================================
# Workload Identity for GCS Access
# =============================================================================

# Dedicated service account for workload identity
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
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.workload_identity.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[jobs/job-runner]"

  depends_on = [kubernetes_service_account.job_runner]
}

# =============================================================================
# Ray Cluster Deployment
# =============================================================================

# Deploy RayCluster after KubeRay operator is ready
resource "kubernetes_manifest" "ray_cluster" {
  manifest = {
    apiVersion = "ray.io/v1"
    kind       = "RayCluster"
    metadata = {
      name      = "ray-cluster"
      namespace = kubernetes_namespace.namespaces["ray-system"].metadata[0].name
    }
    spec = {
      rayVersion             = "2.9.0"
      enableInTreeAutoscaling = true

      headGroupSpec = {
        rayStartParams = {
          "dashboard-host" = "0.0.0.0"
          "block"          = "true"
          "num-cpus"       = "0"
        }
        template = {
          spec = {
            containers = [{
              name  = "ray-head"
              image = "rayproject/ray-ml:2.9.0-py310"
              ports = [
                { containerPort = 6379, name = "gcs-server" },
                { containerPort = 8265, name = "dashboard" },
                { containerPort = 10001, name = "client" }
              ]
              resources = {
                requests = { cpu = "2", memory = "8Gi" }
                limits   = { cpu = "4", memory = "16Gi" }
              }
              volumeMounts = [{ name = "log-volume", mountPath = "/tmp/ray" }]
            }]
            volumes = [{ name = "log-volume", emptyDir = {} }]
            nodeSelector = { workload = "cpu" }
          }
        }
      }

      workerGroupSpecs = [{
        groupName   = "cpu-workers"
        replicas    = 2
        minReplicas = 1
        maxReplicas = 10
        rayStartParams = {
          "block"    = "true"
          "num-cpus" = "4"
        }
        template = {
          spec = {
            containers = [{
              name  = "ray-worker"
              image = "rayproject/ray-ml:2.9.0-py310"
              resources = {
                requests = { cpu = "4", memory = "16Gi" }
                limits   = { cpu = "8", memory = "32Gi" }
              }
              volumeMounts = [{ name = "log-volume", mountPath = "/tmp/ray" }]
            }]
            volumes = [{ name = "log-volume", emptyDir = {} }]
            nodeSelector = { workload = "cpu" }
          }
        }
      }]
    }
  }

  depends_on = [helm_release.kuberay_operator]
}

# Ray head service
resource "kubernetes_service" "ray_head" {
  metadata {
    name      = "ray-cluster-head-svc"
    namespace = kubernetes_namespace.namespaces["ray-system"].metadata[0].name
  }

  spec {
    type = "ClusterIP"
    selector = {
      "ray.io/cluster"   = "ray-cluster"
      "ray.io/node-type" = "head"
    }
    port {
      name        = "gcs-server"
      port        = 6379
      target_port = 6379
    }
    port {
      name        = "dashboard"
      port        = 8265
      target_port = 8265
    }
    port {
      name        = "client"
      port        = 10001
      target_port = 10001
    }
  }

  depends_on = [kubernetes_manifest.ray_cluster]
}

# =============================================================================
# Resource Quotas
# =============================================================================

resource "kubernetes_resource_quota" "jobs_quota" {
  metadata {
    name      = "jobs-resource-quota"
    namespace = kubernetes_namespace.namespaces["jobs"].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "100"
      "requests.memory" = "400Gi"
      "limits.cpu"      = "200"
      "limits.memory"   = "800Gi"
      "pods"            = "100"
      "count/jobs.batch" = "50"
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# =============================================================================
# Network Policies
# =============================================================================

# Network policy for jobs namespace - allow egress to Ray and monitoring
resource "kubernetes_network_policy" "jobs_policy" {
  metadata {
    name      = "jobs-network-policy"
    namespace = kubernetes_namespace.namespaces["jobs"].metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    # Allow all egress (to Ray cluster, GCS, etc.)
    egress {
      to {}
    }

    # Deny all ingress by default (jobs don't need incoming connections)
    ingress {}
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# Network policy for ray-system - allow from jobs namespace
resource "kubernetes_network_policy" "ray_policy" {
  metadata {
    name      = "ray-network-policy"
    namespace = kubernetes_namespace.namespaces["ray-system"].metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "jobs"
          }
        }
      }
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "ray-system"
          }
        }
      }
    }

    egress {
      to {}
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# =============================================================================
# GPU Support (NVIDIA Driver Installer)
# =============================================================================

resource "helm_release" "nvidia_gpu_operator" {
  count = var.enable_gpu_pool ? 1 : 0

  name       = "gpu-operator"
  repository = "https://helm.ngc.nvidia.com/nvidia"
  chart      = "gpu-operator"
  version    = "v23.9.1"
  namespace  = "gpu-operator"

  create_namespace = true

  set {
    name  = "driver.enabled"
    value = "true"
  }

  set {
    name  = "toolkit.enabled"
    value = "true"
  }

  set {
    name  = "devicePlugin.enabled"
    value = "true"
  }

  depends_on = [module.gke]
}

# =============================================================================
# Secrets Management (GCP Secret Manager)
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
