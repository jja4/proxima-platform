# Managed Namespaces
# These namespaces are managed by Terraform because we need to inject
# infrastructure configuration (Secrets, ConfigMaps, ServiceAccounts)
# into them before the applications start.

# External Secrets (Needs Workload Identity ServiceAccount)
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
  depends_on = [module.management_cluster]
}

# Backstage (Needs platform-config ConfigMap)
resource "kubernetes_namespace" "backstage" {
  metadata {
    name = "backstage"
    labels = {
      "managed-by" = "terraform"
    }
  }
  depends_on = [module.management_cluster]
}

# Crossplane (Needs ProviderConfig)
resource "kubernetes_namespace" "crossplane_system" {
  metadata {
    name = "crossplane-system"
    labels = {
      "managed-by" = "terraform"
    }
  }
  depends_on = [module.management_cluster]
}
