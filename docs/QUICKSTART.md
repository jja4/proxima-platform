# Quick Start Guide

Get the ML platform running in minutes.

## Option A: Local Development (Recommended to Start)

Use VS Code Dev Containers to get a fully working environment with Ray, MinIO, and monitoring - no GCP required.

> **Note:** Local dev uses direct Python execution. The `platform` CLI commands are for GKE production only.

### Prerequisites
- VS Code with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Docker Desktop

### Steps

1. **Open in Dev Container**
   ```
   Open this repo in VS Code → Click "Reopen in Container" when prompted
   ```

2. **Wait for setup** (~2 minutes)
   - Ray cluster starts automatically
   - MinIO (S3-compatible storage) starts
   - Prometheus + Grafana start

3. **Run a test job**
   ```bash
   # Direct Python execution (local dev)
   python docs/examples/stellar_optimization/train.py
   ```

4. **Access dashboards**
   | Service | URL | Credentials |
   |---------|-----|-------------|
   | Ray Dashboard | http://localhost:8265 | - |
   | MinIO Console | http://localhost:9001 | minioadmin / minioadmin |
   | Grafana | http://localhost:3000 | admin / admin |
   | Prometheus | http://localhost:9090 | - |

### Local vs Production

| Task | Local Dev | GKE Production |
|------|-----------|----------------|
| Run training | `python train.py` | `platform submit workload:v1` |
| Check status | Check Docker containers | `platform status` |
| View logs | Terminal output | `platform logs job-name` |
| Storage | MinIO (localhost:9000) | Google Cloud Storage |
| Scale workers | `docker-compose scale` | `platform scale 10` |

---

## Option B: GCP Production Deployment

Deploy to GKE for production workloads with autoscaling and GPUs.

> **Note:** The `platform` CLI commands work here, interacting with kubectl and GCP.

### Prerequisites

- GCP account with billing
- `gcloud` CLI installed
- `terraform` >= 1.5.0
- `kubectl` installed
- Docker installed

### Step 1: Set Up GCP (5 min)

```bash
# Set project
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"

# Authenticate
gcloud auth login
gcloud auth application-default login
gcloud config set project $PROJECT_ID

# Enable APIs
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  storage.googleapis.com

# Create Terraform state bucket
gsutil mb -l $REGION gs://${PROJECT_ID}-terraform-state
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

### Step 2: Deploy Platform (15 min)

```bash
cd terraform/envs/dev

# Configure
cp terraform.tfvars.example terraform.tfvars
sed -i '' "s/your-gcp-project-id/${PROJECT_ID}/g" terraform.tfvars

# Update backend bucket in main.tf
sed -i '' "s/SET_YOUR_BUCKET_NAME/${PROJECT_ID}-terraform-state/g" main.tf

# Deploy
terraform init
terraform plan
terraform apply  # Type 'yes' when prompted
```

**☕ This takes ~15 minutes. Grab coffee!**

### Step 3: Connect to Cluster (2 min)

```bash
# Get credentials
gcloud container clusters get-credentials ml-platform-gke \
  --region $REGION --project $PROJECT_ID

# Verify
kubectl get nodes
kubectl get pods -A

# Check Ray cluster
kubectl get rayclusters -n ray-system
```

### Step 4: Submit First Job (5 min)

```bash
# Configure Docker
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build example workload
cd docs/examples/stellar_optimization
export IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/ml-platform-ml/stellar-opt:v1"

docker build -t $IMAGE .
docker push $IMAGE

# Update job manifest
sed -i '' "s/PROJECT_ID/${PROJECT_ID}/g" k8s-job.yaml

# Submit job
kubectl apply -f k8s-job.yaml

# Watch logs
kubectl logs -n jobs -l app=stellar-opt -f
```

### Step 5: Access Dashboards (3 min)

```bash
# Ray Dashboard
kubectl port-forward -n ray-system svc/ray-cluster-head-svc 8265:8265 &
open http://localhost:8265

# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
open http://localhost:3000
# Login: admin / admin
```

## Success! 🎉

You now have:
- ✅ GKE cluster running
- ✅ Ray cluster deployed
- ✅ Training job submitted
- ✅ Monitoring dashboards accessible

## What's Next?

### Deploy Your Own Workload

```bash
# Copy example
cp -r docs/examples/stellar_optimization docs/examples/my_workload

# Modify
cd docs/examples/my_workload
vim main.py  # Add your code

# Build & deploy
docker build -t my-workload:v1 .
# ... push and apply
```

### Scale Up

```bash
# More Ray workers
kubectl scale raycluster ray-cluster --replicas=10 -n ray-system

# Enable GPU nodes
# Edit terraform/envs/dev/main.tf:
enable_gpu_pool = true

terraform apply
```

### Monitor Costs

```bash
# View resources
kubectl top nodes
kubectl top pods -A

# Check GCP Console
open https://console.cloud.google.com/billing
```

## Troubleshooting

**Terraform fails:**
```bash
# Check quota
gcloud compute project-info describe --project=$PROJECT_ID

# Request increase if needed
```

**Job won't start:**
```bash
kubectl describe job -n jobs JOB_NAME
kubectl get events -n jobs
```

**Can't connect to cluster:**
```bash
gcloud container clusters get-credentials ml-platform-gke \
  --region $REGION --project $PROJECT_ID
```

## Cleanup

```bash
# Destroy infrastructure
cd terraform/envs/dev
terraform destroy

# Delete state bucket
gsutil rm -r gs://${PROJECT_ID}-terraform-state
```

## Documentation

- [GitHub Actions Setup](GITHUB_ACTIONS.md) - CI/CD configuration
- [Examples](examples/) - Example workloads

## Support

- Issues: GitHub Issues
- Examples: `docs/examples/` directory
