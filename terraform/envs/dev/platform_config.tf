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
