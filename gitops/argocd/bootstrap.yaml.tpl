# Bootstrap Application - ArgoCD Self-Management
# This Application tells ArgoCD to manage itself from the gitops/argocd/ directory
# After Terraform applies this, ArgoCD takes full control of its own configuration
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-self-managed
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
