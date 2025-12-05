# Quick Start Guide

Get up and running with the Constellaration ML Training Platform.

---

## Choose Your Path

| I want to... | Guide |
|--------------|-------|
| **Develop & test locally** | [DEV_GUIDE.md](DEV_GUIDE.md) |
| **Deploy infrastructure to GCP** | [LAUNCH_PLATFORM.md](LAUNCH_PLATFORM.md) |
| **Operate the production platform** | [USE_PLATFORM.md](USE_PLATFORM.md) |

---

## 5-Minute Quick Start

### Step 1: Open Dev Container

1. Clone this repo
2. Open in VS Code
3. Click **"Reopen in Container"** when prompted
4. Wait ~2 minutes for setup

When ready:
```
✅ Platform ready! Ray cluster, MinIO, and monitoring are running.
   Ray Dashboard: http://localhost:8265
   MinIO Console: http://localhost:9001
   Grafana:       http://localhost:3000
```

### Step 2: Run Training Locally

```bash
# Run example training job
python docs/examples/stellar_optimization/train.py
```

### Step 3: Deploy to Production (Optional)

```bash
# Authenticate with GCP
export PROJECT_ID="your-gcp-project-id"
gcloud auth login
gcloud config set project $PROJECT_ID

# Deploy infrastructure (~15 min)
# Advised to set up a Service Account with necessary permissions first:
# follow setup-terraform-service-account.sh in terraform/
# Them, follow procedures in LAUNCH_PLATFORM.md for detailed instructions
cd terraform/envs/dev
terraform init && terraform apply

# Connect to cluster
gcloud container clusters get-credentials ml-platform-gke \
  --region europe-west3 --project $PROJECT_ID

# Build and submit job
ml-platform build stellar_optimization v1.0.0
ml-platform submit stellar_optimization:v1.0.0

# Monitor
ml-platform logs stellar_optimization-YYYYMMDD-HHMMSS
```

---

## Platform CLI Commands

```bash
ml-platform status                    # Show cluster health
ml-platform build <name> <version>    # Build & push container
ml-platform submit <name>:<version>   # Submit training job
ml-platform logs <job-name>           # View job logs
ml-platform list                      # List all jobs
ml-platform scale <replicas>          # Scale Ray workers
platform port-forward all          # Access dashboards
```

---

## Documentation

| Guide | Description |
|-------|-------------|
| [DEV_GUIDE.md](DEV_GUIDE.md) | Local development, testing, creating workloads |
| [LAUNCH_PLATFORM.md](LAUNCH_PLATFORM.md) | Terraform deployment, GCP setup, infrastructure |
| [USE_PLATFORM.md](USE_PLATFORM.md) | Operations, monitoring, scaling, troubleshooting |
| [examples/stellar_optimization/](examples/stellar_optimization/) | Example workload with full documentation |
