# Bootstrap Application - ArgoCD Self-Management + Root ApplicationSet
# This Application tells ArgoCD to:
# 1. Manage itself from the gitops/argocd/ directory (including the root ApplicationSet)
# 2. Deploy the root ApplicationSet which auto-discovers all apps
# After Terraform applies this, ArgoCD takes full control of the platform
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
    path: gitops/argocd
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
