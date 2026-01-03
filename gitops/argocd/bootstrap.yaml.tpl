# Bootstrap Application - GitOps Handoff
# This is the bridge from Terraform to GitOps:
# 1. Terraform installs ArgoCD and creates this Application
# 2. This Application directly syncs all Application manifests in gitops/
#    (no wrapper ApplicationSet), excluding the argocd folder
# Result: Declarative, self-healing platform managed entirely from Git
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-bootstrap
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: ${repo_url}
    targetRevision: gitops
    path: gitops
    directory:
      recurse: true
      include: "{**/application.yaml,projects/*.yaml,clusters/**/namespaces.yaml,infrastructure/config/platform-config.yaml}"
      exclude: "argocd/**"
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
