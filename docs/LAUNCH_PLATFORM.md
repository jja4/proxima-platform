# Launch Platform Guide

This guide walks you through deploying the complete ML platform infrastructure on Google Cloud Platform using Terraform.

---

## Overview

The platform deploys these GCP resources:

```
┌─────────────────────────────────────────────────────────────┐
│  Google Cloud Platform                                      │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  GKE Cluster                                         │   │
│  │                                                      │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │   │
│  │  │ Ray Head    │  │ Ray Workers │  │ Monitoring   │  │   │
│  │  │ (Dashboard) │  │ (CPU/GPU)   │  │ (Prom/Graf)  │  │   │
│  │  └─────────────┘  └─────────────┘  └──────────────┘  │   │
│  │                                                      │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │  Training Jobs Namespace                        │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐    │
│  │ Artifact     │  │ Cloud        │  │ Secret          │    │
│  │ Registry     │  │ Storage      │  │ Manager         │    │
│  └──────────────┘  └──────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Resources created:**
- VPC network with subnet and secondary IP ranges
- GKE cluster with autoscaling node pools
- KubeRay operator and Ray cluster
- Prometheus + Grafana monitoring stack
- Artifact Registry for container images
- Cloud Storage bucket for ML artifacts
- Secret Manager for credentials
- IAM service accounts and workload identity

---

## Prerequisites

### 1. GCP Project

You need a GCP project with billing enabled. Note your **Project ID** (not display name).

### 2. Required Permissions

Your account needs these IAM roles:
- `roles/owner` OR the following specific roles:
  - `roles/compute.admin`
  - `roles/container.admin`
  - `roles/iam.serviceAccountAdmin`
  - `roles/iam.serviceAccountUser` 
  - `roles/storage.admin`
  - `roles/artifactregistry.admin`
  - `roles/secretmanager.admin`


### 3. GCP CLI & Authentication

```bash
# Install gcloud CLI if not present
# https://cloud.google.com/sdk/docs/install

# Set your project ID
export PROJECT_ID="your-gcp-project-id"
export REGION="europe-west3"
```

#### Option A: Interactive Login (Recommended for Developers)

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project $PROJECT_ID
```

#### Option B: Service Account (For CI/CD or Headless)
The `terraform/setup-terraform-service-account.sh` script automatically:
- Enables required GCP APIs
- Creates a service account (`terraform-sa`)
- Grants all necessary IAM roles (including `iam.serviceAccountUser` for GKE)
- Creates and saves the service account key

```bash
# Create service account and grant all required roles (one-time setup)
# This script enables APIs, creates the service account, and grants necessary IAM roles
./terraform/setup-terraform-service-account.sh

# Use the service account
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/terraform-key.json"
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
gcloud config set project $PROJECT_ID
```


---

## Step 1: Create Terraform State Bucket

Terraform state must be stored in a GCS bucket for team collaboration and state locking.

```bash
# Create bucket for Terraform state
gsutil mb -l $REGION gs://${PROJECT_ID}-terraform-state

# Enable versioning (for state recovery)
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

---

## Step 2: Configure Terraform Variables

```bash
cd terraform/envs/dev

# Create your configuration
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
project_id             = "your-gcp-project-id"     # Required
project_name           = "ml-platform"             # Prefix for resources
region                 = "europe-west3"            # GCP region
cluster_location       = "europe-west3-a"          # Optional zonal override for GKE
enable_gpu_pool        = false                     # Set true for GPU support
grafana_admin_password = "your-secure-password"    # Change this!
terraform_user_list    = ["user:you@example.com"]  # Principals running/updating terraform
```

### Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `project_id` | (required) | Your GCP project ID |
| `project_name` | `ml-platform` | Resource name prefix |
| `region` | `europe-west3` | GCP region |
| `cluster_location` | `""` (falls back to region) | Optional zone for the cluster/node pools |
| `enable_gpu_pool` | `false` | Enable GPU node pool (adds cost) |
| `grafana_admin_password` | `changeme-in-production` | Grafana admin password |
| `terraform_user_list` | `[]` | Principals granted `iam.serviceAccountUser` on the node SA |

Terraform grants the `roles/iam.serviceAccountUser` binding on the node service account to every entry in `terraform_user_list`, so whoever runs `terraform apply` can attach that service account to the node VMs without extra manual steps. Specify members with the standard prefixes (`user:`, `serviceAccount:`, `group:`).

---

## Step 3: Configure State Backend

Update the Terraform backend configuration in `main.tf`.
Can be done manually here or during terraform init in Step 4.
This is so Terraform knows where to store the state file.
```bash
# Automatically update the bucket name
sed -i '' "s/SET_YOUR_BUCKET_NAME/${PROJECT_ID}-terraform-state/g" main.tf
```
---

## Step 4: Deploy Infrastructure

```bash
# Initialize Terraform (downloads providers, configures backend)
# this will replace in main.tf the placeholder with your bucket name 
#  backend "gcs" {
#    bucket = "SET_YOUR_BUCKET_NAME"  # Update this
#    prefix = "dev"
#  }
terraform init \
  -backend-config="bucket=${PROJECT_ID}-terraform-state" \
  -backend-config="prefix=dev"

# Preview changes
terraform plan

# Deploy (type 'yes' when prompted)
terraform apply
```

☕ **This takes approximately 15-20 minutes** on first deployment.

### What Gets Created

1. **APIs Enabled** (~1 min)
   - Compute Engine, Container, Artifact Registry, Storage, Logging, Monitoring

2. **VPC Network** (~2 min)
   - VPC, subnet, secondary ranges for pods/services

3. **GKE Cluster** (~10 min)
   - Control plane, node pools, autoscaling

4. **Kubernetes Resources** (~3 min)
   - Namespaces, RBAC, resource quotas, network policies

5. **KubeRay Operator** (~2 min)
   - Helm chart deployment, Ray cluster

6. **Monitoring Stack** (~4 min)
   - Prometheus, Grafana, dashboards

7. **Supporting Resources** (~1 min)
   - Artifact Registry, GCS bucket, Secret Manager

---

## Step 5: Connect to Cluster

After successful deployment, connect kubectl to the cluster:

```bash
# Get cluster credentials
gcloud container clusters get-credentials ml-platform-gke \
  --region $REGION \
  --project $PROJECT_ID

# Verify connection
kubectl get nodes

# Check ml-platform status
ml-platform status
```

Expected output:
```
🔍 Platform Status

Cluster:
  Nodes: 3

Ray Cluster:
  Running pods: 3

Jobs:
  Total: 0
  Completed: 0
  Running: 0
```

---

## Step 6: Verify Deployment

### Check All Components

```bash
# GKE nodes
kubectl get nodes

# Ray cluster
kubectl get pods -n ray-system

# Monitoring stack
kubectl get pods -n monitoring

# Jobs namespace
kubectl get all -n jobs
```

### Access Dashboards

```bash
# Port-forward to access dashboards
ml-platform port-forward all

# Individual dashboards
ml-platform port-forward ray       # http://localhost:8265
ml-platform port-forward grafana   # http://localhost:3000
ml-platform port-forward prometheus # http://localhost:9090
```

### Configure Docker for Artifact Registry

```bash
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

---

## Terraform Outputs

After deployment, view useful outputs:

```bash
terraform output
```

Key outputs:
- `cluster_endpoint` - GKE cluster API endpoint
- `artifact_registry_url` - Container registry URL
- `storage_bucket` - GCS bucket for artifacts
- `ray_head_service` - Ray head service address

---

## Modifying Infrastructure

### Scale Node Pools

Edit `terraform.tfvars`:
```hcl
cpu_min_nodes = 1
cpu_max_nodes = 10  # Increase for more capacity
```

Then apply:
```bash
terraform apply
```

### Enable GPU Support

1. Edit `terraform.tfvars`:
   ```hcl
   enable_gpu_pool = true
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

3. Verify GPU nodes:
   ```bash
   kubectl get nodes -l cloud.google.com/gke-accelerator
   ```

### Change Machine Types

Edit the GKE module configuration in `main.tf`:
```hcl
module "gke" {
  # ...
  cpu_machine_type = "n2-standard-8"  # Larger machines
}
```

---

## Cost Management

### Estimated Monthly Costs (Dev Environment)

| Resource | Specification | Est. Cost/Month |
|----------|---------------|-----------------|
| GKE Control Plane | Zonal | Free |
| CPU Node Pool | 3x n2-standard-4 (preemptible) | ~$80 |
| Storage | 100GB | ~$2 |
| Artifact Registry | Per storage | ~$1 |
| Network | Egress | Variable |
| **Total (Dev)** | | **~$100-150/month** |

### Cost Optimization Tips

1. **Use preemptible VMs** (enabled by default in dev)
   ```hcl
   use_preemptible = true  # 60-80% cheaper
   ```

2. **Scale down when not in use**
   ```bash
   # Scale Ray workers to zero
   ml-platform scale 0
   
   # Or destroy entire infrastructure
   terraform destroy
   ```

3. **Set node pool limits**
   ```hcl
   cpu_min_nodes = 0  # Scale to zero
   cpu_max_nodes = 5  # Cap maximum
   ```

4. **Enable GKE cluster autoscaling** (enabled by default)

---

## Cleanup

### Pre-Destroy Checklist

**Before running `terraform destroy`, complete these steps to ensure a clean teardown:**

1. **Authenticate with your personal Google account** (not terraform service account):
   ```bash
   gcloud auth login
   gcloud config set project ${PROJECT_ID}
   ```

2. **Scale down Ray cluster** (prevents hanging pods):
   ```bash
   ml-platform scale 0
   ```

3. **Delete all jobs** (prevents orphaned resources):
   ```bash
   kubectl delete jobs -n jobs --all
   ```

4. **Verify no forwarding rules exist** (can block VPC deletion):
   ```bash
   gcloud compute forwarding-rules list --project=${PROJECT_ID}
   ```

5. **Verify deletion protection is disabled** (GKE cluster):
   ```bash
   # Should show deletion_protection = false in terraform code
   grep "deletion_protection" terraform/modules/gke/main.tf
   ```

### Destroy All Infrastructure

```bash
cd terraform/envs/dev

# Preview destruction
terraform plan -destroy -var="project_id=${PROJECT_ID}"

# Destroy with auto-approve
terraform destroy -var="project_id=${PROJECT_ID}" -auto-approve
```

**If destroy fails with network/forwarding rule errors:**

```bash
# Remove VPC from state (Terraform can't delete it due to phantom references)
terraform state rm module.vpc.google_compute_network.vpc
terraform state rm module.vpc.google_compute_router.router
terraform state rm module.vpc.google_compute_router_nat.nat

# Retry destroy
terraform destroy -var="project_id=${PROJECT_ID}" -auto-approve

# Manually delete VPC after Terraform completes
gcloud compute networks delete ml-platform-vpc --project=${PROJECT_ID}
```

⚠️ **Warning**: This deletes ALL resources including:
- GKE cluster and all workloads
- Storage bucket and contents (ml-artifacts)
- Artifact Registry and images
- Service accounts and IAM bindings

### Delete State Bucket (Manual Step!)

> **Important**: The Terraform state bucket is NOT deleted by `terraform destroy`.
> You must delete it manually when completely done with the project.

```bash
# Delete state bucket (only after terraform destroy!)
gsutil rm -r gs://${PROJECT_ID}-terraform-state
```

**Why?** Terraform needs the state bucket to know what resources to destroy. Deleting it during `terraform destroy` would break the process.

---

## Troubleshooting

### Terraform Init Fails

```bash
# Check GCP authentication
gcloud auth list
gcloud config get-value project

# Re-authenticate
gcloud auth application-default login
```

### API Not Enabled

```bash
# Enable required APIs manually
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable storage.googleapis.com
```

### Quota Exceeded

```bash
# Check project quotas
gcloud compute project-info describe --project=$PROJECT_ID

# Request quota increase in GCP Console
# IAM & Admin > Quotas
```

### Cluster Connection Issues

```bash
# Re-fetch credentials
gcloud container clusters get-credentials ml-platform-gke \
  --region $REGION --project $PROJECT_ID

# Check cluster status
gcloud container clusters describe ml-platform-gke \
  --region $REGION --project $PROJECT_ID
```

### State Lock Issues

```bash
# If Terraform state is locked
terraform force-unlock LOCK_ID
```

## Note: Ray `num-cpus` vs pod CPU requests

- Ensure `rayStartParams["num-cpus"]` matches the container `requests.cpu` in the Ray pod spec. If Ray advertises more CPUs per worker than Kubernetes schedules (for example Ray thinks a worker has 4 CPUs but the pod requests 1 CPU), Ray's scheduler and autoscaler can make incorrect placement decisions.
- In this repo the dev sizing uses small nodes and conservative quotas. We recommend:
   - set `num-cpus` = `1` for head and workers in dev
   - set the container CPU *limit* equal to the *request* for stricter enforcement (`limits.cpu = requests.cpu`)
   -  let memory limits be larger than memory requests so pods can tolerate occasional memory spikes, but keeping CPU limits equal to CPU requests so Ray and Kubernetes don’t get mismatched 

Example (Terraform / YAML):
```hcl
# head: requests.cpu = "1", limits.cpu = "1", rayStartParams["num-cpus"] = "1"
# worker: requests.cpu = "1", limits.cpu = "1", rayStartParams["num-cpus"] = "1"
```
---

## Next Steps

Once infrastructure is deployed:

1. **Build and submit workloads**: See [USE_PLATFORM.md](USE_PLATFORM.md)
2. **Monitor the platform**: See [USE_PLATFORM.md](USE_PLATFORM.md)
3. **Set up CI/CD**: See [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)

---
