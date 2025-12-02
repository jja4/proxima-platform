# Quick Start Guide

This guide helps ML engineers get started with the Constellaration platform for distributed training.

---

## Using the Dev Container

The dev container is your **unified development environment**. It comes pre-configured with everything you need:

- **Python 3.10** with `uv` package manager
- **Ray** for distributed computing
- **kubectl, helm, terraform, gcloud** CLI tools
- **Docker** access (build containers from inside)
- **VS Code extensions** for Python, Terraform, Kubernetes

### What Can You Do in the Dev Container?

| Workflow | How | When to Use |
|----------|-----|-------------|
| **Develop & test locally** | `python train.py` | Iterate quickly without GCP costs |
| **Deploy to GKE** | `terraform apply` | Set up production infrastructure |
| **Submit jobs to GKE** | `platform submit workload:v1` | Run production training jobs |
| **Monitor GKE cluster** | `platform status`, `platform logs` | Check job status |
| **Build containers** | `docker build` | Package workloads for production |

The dev container supports **both local development AND production operations** - you don't need to leave it.

---

## Getting Started

### Prerequisites
- VS Code with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Docker Desktop running

### Step 1: Open in Dev Container

```
1. Clone this repo
2. Open in VS Code
3. Click "Reopen in Container" when prompted (or Cmd+Shift+P → "Dev Containers: Reopen in Container")
4. Wait ~2 minutes for setup
```

When ready, you'll see:
```
✅ Platform ready! Ray cluster, MinIO, and monitoring are running.
   Ray Dashboard: http://localhost:8265
   MinIO Console: http://localhost:9001
   Grafana:       http://localhost:3000
```

### Step 2: Choose Your Workflow

---

## Workflow A: Local Development (No GCP)

Perfect for developing and testing your training code before deploying to production.

### What's Running Locally

The dev container automatically starts:
- **Ray cluster** (1 head + 2 workers) - distributed computing
- **MinIO** - S3-compatible storage (replaces GCS locally)
- **Prometheus + Grafana** - monitoring

### Run Training Locally

```bash
# Run example training job
python docs/examples/stellar_optimization/train.py

# Or connect to Ray programmatically
python -c "import ray; ray.init('ray://localhost:10001'); print(ray.cluster_resources())"
```

### Access Local Dashboards

| Service | URL | Credentials |
|---------|-----|-------------|
| Ray Dashboard | http://localhost:8265 | - |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |
| Grafana | http://localhost:3000 | admin / admin |

### Develop Your Own Workload

```bash
# Copy example as template
cp -r docs/examples/stellar_optimization docs/examples/my_experiment

# Edit your training code
code docs/examples/my_experiment/train.py

# Test locally
python docs/examples/my_experiment/train.py
```

---

## Workflow B: GKE Production Deployment

When you're ready for production: autoscaling, GPUs, and persistent storage.

### Step 1: Authenticate with GCP

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"
export REGION="europe-west3"

# Option A: Interactive login (opens browser)
gcloud auth login
gcloud auth application-default login

# Option B: Service account (for CI/CD or headless)
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/terraform-key.json"
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS

# Set project
gcloud config set project $PROJECT_ID
```

### Step 2: Create Terraform State Bucket

```bash
# Create bucket for Terraform state
gsutil mb -l $REGION gs://${PROJECT_ID}-terraform-state
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

### Step 3: Configure Terraform

```bash
cd terraform/envs/dev

# Create your config
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
project_id             = "your-gcp-project-id"  # ← Your GCP project ID
project_name           = "ml-platform"
region                 = "europe-west3"
enable_gpu_pool        = false                   # Set true if you need GPUs
grafana_admin_password = "your-secure-password"
```

Update the backend bucket in `main.tf`:
```bash
sed -i '' "s/SET_YOUR_BUCKET_NAME/${PROJECT_ID}-terraform-state/g" main.tf
```

### Step 4: Deploy Infrastructure (~15 min)

```bash
terraform init
terraform plan    # Review what will be created
terraform apply   # Type 'yes' to confirm
```

☕ **This takes ~15 minutes.** Terraform creates:
- VPC network
- GKE cluster with autoscaling
- Ray cluster (via KubeRay operator)
- Artifact Registry for container images
- Cloud Storage bucket for artifacts
- Prometheus + Grafana monitoring

### Step 5: Connect to Cluster

```bash
# Get kubectl credentials
gcloud container clusters get-credentials ml-platform-gke \
  --region $REGION --project $PROJECT_ID

# Verify connection
kubectl get nodes
platform status
```

### Step 6: Submit Your First Job

```bash
# Configure Docker for Artifact Registry
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build and push your workload
cd docs/examples/stellar_optimization
platform build stellar_optimization v1.0.0

# Submit to GKE
platform submit stellar_optimization:v1.0.0

# Watch logs
platform logs stellar-optimization-YYYYMMDD-HHMMSS
```

---

## Platform CLI Reference

Once connected to GKE, use these commands:

```bash
platform status                    # Show cluster health
platform build <name> <version>    # Build & push container to Artifact Registry
platform submit <name>:<version>   # Submit training job to GKE
platform logs <job-name>           # View job logs
platform list                      # List all jobs
platform scale <replicas>          # Scale Ray workers
platform port-forward ray          # Access Ray dashboard
platform port-forward grafana      # Access Grafana
```

---

## Local vs Production Comparison

| Aspect | Local (Dev Container) | Production (GKE) |
|--------|----------------------|------------------|
| **Start training** | `python train.py` | `platform submit workload:v1` |
| **Storage** | MinIO (localhost:9000) | Google Cloud Storage |
| **Compute** | Docker containers (2 workers) | Kubernetes pods (autoscaling) |
| **GPUs** | Not available | NVIDIA T4/A100 |
| **Cost** | Free | Pay for GCP resources |
| **Use case** | Development, testing | Production, large-scale |

---

## Troubleshooting

### Dev Container Issues

```bash
# Ray not connecting
docker-compose -f .devcontainer/docker-compose.yml logs ray-head

# Restart local services
docker-compose -f .devcontainer/docker-compose.yml restart
```

### GKE Issues

```bash
# Terraform fails - check quotas
gcloud compute project-info describe --project=$PROJECT_ID

# Can't connect to cluster
gcloud container clusters get-credentials ml-platform-gke \
  --region $REGION --project $PROJECT_ID

# Job won't start
kubectl describe job -n jobs JOB_NAME
kubectl get events -n jobs
```

### Cleanup GKE Resources

```bash
cd terraform/envs/dev
terraform destroy

# Delete state bucket
gsutil rm -r gs://${PROJECT_ID}-terraform-state
```

---

## Next Steps

- [Example Workloads](examples/) - More training examples
- [GitHub Actions Setup](GITHUB_ACTIONS_SETUP.md) - CI/CD automation
