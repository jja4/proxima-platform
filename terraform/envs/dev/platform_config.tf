# =============================================================================
# PLATFORM CONFIGURATION (In-Cluster Resources)
# =============================================================================
# This file contains all Kubernetes resources that are injected into the cluster
# by Terraform. This includes:
# 1. ArgoCD Bootstrap Configuration (Repositories, Clusters, Base Apps)
# 2. Infrastructure Configuration (External Secrets, Crossplane)
# 3. Application Configuration (Backstage ConfigMaps)
#
# These resources bridge the gap between "Infrastructure" (GCP/Clusters) and
# "Applications" (GitOps).

# -----------------------------------------------------------------------------
# 1. ARGOCD BOOTSTRAP
# -----------------------------------------------------------------------------

# Bootstrap ArgoCD with minimal configuration
# ArgoCD will immediately take over its own management from the gitops/ directory
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.12"
  namespace        = "argocd"
  create_namespace = true

  # Minimal bootstrap config - ArgoCD will manage its full config from Git
  set {
    name  = "server.insecure"
    value = "true"  # TLS will be added later via cert-manager
  }

  set {
    name  = "configs.params.application.namespaces"
    value = "argocd"  # Allow ArgoCD to manage apps in its own namespace
  }

  # Configure External Secrets ServiceAccount with Workload Identity
  set {
    name  = "configs.secret.create"
    value = "false"  # We'll create the repo Secret via Terraform
  }

  # Wait for ArgoCD to be ready before applying GitOps manifests
  wait    = true
  timeout = 600

  depends_on = [module.management_cluster]
}

# Create the "Seed" Secret for ArgoCD
# This registers the repository AND provides environment metadata (project-id, region)
resource "kubernetes_secret" "argocd_repo" {
  metadata {
    name      = "proxima-platform-repo"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    name       = "proxima-platform"
    type       = "git"
    url        = var.git_repo_url
    project-id = var.project_id
    region     = var.region
    zone       = var.management_cluster_zone
  }

  depends_on = [helm_release.argocd]
}

# Apply the bootstrap Application (The Handoff)
resource "kubectl_manifest" "argocd_bootstrap" {
  yaml_body = templatefile("${path.module}/../../../gitops/argocd/bootstrap.yaml.tpl", {
    repo_url = var.git_repo_url
  })

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.argocd_repo,
    kubernetes_service_account.external_secrets
  ]
}

# Deploy AppProjects (Security Boundaries) first
resource "kubectl_manifest" "platform_team_project" {
  yaml_body = file("${path.module}/../../../gitops/security/platform-team.yaml")

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "workload_teams_project" {
  yaml_body = file("${path.module}/../../../gitops/security/workload-teams.yaml")

  depends_on = [helm_release.argocd]
}

# Register the Management Cluster (Local) with metadata
resource "kubernetes_secret" "management_cluster" {
  metadata {
    name      = "management-cluster-secret"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "cluster-name"                  = "management-cluster"
      "cluster-type"                  = "management"
    }
    annotations = {
      "repo-url" = var.git_repo_url
    }
  }

  data = {
    name   = "management-cluster"
    server = "https://kubernetes.default.svc"
    config = jsonencode({
      tlsClientConfig = {
        insecure = true
      }
    })
  }

  depends_on = [helm_release.argocd]
}

# Create workload cluster registration Secret
resource "kubernetes_secret" "workload_cluster" {
  metadata {
    name      = "workload-cluster-secret"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "cluster-name"                  = "workload-cluster"
      "cluster-type"                  = "workload"
    }
    annotations = {
      "repo-url" = var.git_repo_url
    }
  }

  data = {
    name   = "workload-cluster"
    server = "https://${module.workload_cluster.cluster_endpoint}"
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
        caData   = base64encode(module.workload_cluster.cluster_ca_certificate)
      }
    })
  }

  depends_on = [
    helm_release.argocd,
    module.workload_cluster
  ]
}

# Management Cluster Base Configuration (Deploy namespaces, rbac, etc.)
resource "kubectl_manifest" "management_base" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: management-base
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: platform-team
  source:
    repoURL: ${var.git_repo_url}
    targetRevision: gitops
    path: gitops/clusters/management-cluster
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

  depends_on = [helm_release.argocd]
}

# Workload Cluster Base Configuration (Deploy namespaces, rbac, etc.)
resource "kubectl_manifest" "workload_base" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: workload-base
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: platform-team
  source:
    repoURL: ${var.git_repo_url}
    targetRevision: gitops
    path: gitops/clusters/workload-cluster
  destination:
    name: workload-cluster
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.workload_cluster # Wait for cluster registration
  ]
}

# Ray Cluster Instance (Workload Cluster)
# Defined here to inject the git_repo_url dynamically
resource "kubectl_manifest" "ray_cluster" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ray-cluster
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: platform-team
  source:
    repoURL: ${var.git_repo_url}
    targetRevision: gitops
    path: kubernetes/ray
  destination:
    name: workload-cluster
    namespace: ray-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.workload_cluster
  ]
}

# -----------------------------------------------------------------------------
# 2. INFRASTRUCTURE CONFIGURATION
# -----------------------------------------------------------------------------

# Create the External Secrets ServiceAccount
# We do this in Terraform so we can use standard depends_on for Workload Identity
# Namespace is defined in namespaces.tf
resource "kubernetes_service_account" "external_secrets" {
  metadata {
    name      = "external-secrets"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.eso_workload_identity.email
    }
  }
}

resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: gcpsm-secret-store
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  provider:
    gcpsm:
      projectID: ${var.project_id}
      auth:
        workloadIdentity:
          clusterLocation: ${var.management_cluster_zone}
          clusterName: management-cluster
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
YAML

  depends_on = [module.management_cluster]
}

resource "kubectl_manifest" "crossplane_provider_config" {
  yaml_body = <<YAML
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  projectID: ${var.project_id}
  credentials:
    source: InjectedIdentity
YAML

  depends_on = [module.management_cluster]
}

# RBAC for Crossplane StoreConfig (required for External Secret Stores if enabled, or general management)
resource "kubectl_manifest" "crossplane_storeconfig_role" {
    yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: crossplane-storeconfig-manager
rules:
- apiGroups: ["secrets.crossplane.io"]
  resources: ["storeconfigs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
YAML
    depends_on = [module.management_cluster]
}

resource "kubectl_manifest" "crossplane_storeconfig_binding" {
    yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: crossplane-storeconfig-binding
subjects:
- kind: ServiceAccount
  name: crossplane
  namespace: crossplane-system
roleRef:
  kind: ClusterRole
  name: crossplane-storeconfig-manager
  apiGroup: rbac.authorization.k8s.io
YAML
    depends_on = [module.management_cluster]
}

# -----------------------------------------------------------------------------
# 3. APPLICATION CONFIGURATION
# -----------------------------------------------------------------------------

# Platform configuration for Backstage (to avoid hardcoding in Git)
resource "kubectl_manifest" "backstage_platform_config" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-config
  namespace: backstage
data:
  project_id: ${var.project_id}
  region: ${var.region}
  github_raw_base_url: ${replace(replace(var.git_repo_url, "github.com", "raw.githubusercontent.com"), ".git", "")}
YAML
  depends_on = [module.management_cluster]
}
