# Bootstrap Application - GitOps Handoff
# This is the bridge from Terraform to GitOps:
# 1. Terraform installs ArgoCD and creates this Application
# 2. This Application syncs gitops/argocd/ directory (contains root ApplicationSet)
# 3. Root ApplicationSet auto-discovers and deploys all platform apps
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
