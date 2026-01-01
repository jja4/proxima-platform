# GitOps Directory Structure

This directory contains the declarative configuration for the ML Platform, managed by ArgoCD using the ApplicationSet pattern.

## Architecture

```
gitops/
├── argocd/                    # ArgoCD bootstrap (Entry point)
│   └── root-applicationset.yaml   # Auto-discovers all apps
├── projects/                  # ArgoCD RBAC Projects
│   ├── platform-team.yaml     # Full access for platform team
│   └── workload-teams.yaml    # Restricted access for scientists
├── infrastructure/            # Platform infrastructure (Sync Wave 2-3)
│   ├── external-secrets-operator/
│   ├── crossplane/
│   └── cert-manager/
├── apps/                      # Applications (Sync Wave 4-5)
│   ├── backstage/
│   ├── grafana/
│   └── ray-operator/
└── clusters/                  # Cluster-specific config
    ├── management/            # Management cluster (runs ArgoCD)
    └── workload/              # Workload cluster (runs Ray jobs)
```

## Deployment Flow

### 1. Bootstrap via Terraform (Automated)
```bash
# Update git_repo_url in terraform/envs/dev/terraform.tfvars first
cd terraform/envs/dev
terraform apply
```

This automatically:
1. Creates GKE clusters, VPC, IAM
2. Installs ArgoCD with minimal config
3. Registers your Git repository with ArgoCD
4. Applies bootstrap.yaml (hands off to GitOps)
5. ArgoCD takes over and syncs everything from Git

### 2. ArgoCD Auto-Syncs (No Manual Steps)
ArgoCD will automatically:
- Update itself from `argocd-helm.yaml`
- Deploy RBAC projects
- Deploy infrastructure (External Secrets, Crossplane, Cert-Manager)
- Deploy apps (Grafana, Backstage, Ray Operator)
- **Register workload cluster automatically** (via Crossplane or secret)

## Sync Waves

Applications are deployed in order using sync waves:
- **Wave 0-1**: Namespaces
- **Wave 2-3**: Infrastructure (ESO, Crossplane, Cert-Manager)
- **Wave 4-5**: Applications (Grafana, Backstage, Ray Operator)

## RBAC

### Platform Team (`platform-team` project)
- Full access to all namespaces and clusters
- Can deploy infrastructure and apps
- Can exec into pods

### Data Science Team (`workload-teams` project)
- Limited to `jobs` and `experiments` namespaces on workload cluster
- Can deploy Ray jobs and clusters
- Cannot modify infrastructure or networking

## Configuration

### Git Repository URL
Securely stored in GCP Secret Manager:
- Edit: `terraform/envs/dev/terraform.tfvars`
- Variable: `git_repo_url`
- Terraform stores it in Secret Manager
- External Secrets Operator syncs it to ArgoCD
- All GitOps manifests reference it by name: `proxima-platform`
- **Never stored as plain K8s Secret**

### Project IDs
Update in External Secrets and Crossplane configurations:
- `gitops/infrastructure/external-secrets/secret-store.yaml`
- `gitops/infrastructure/crossplane/provider-config.yaml`
