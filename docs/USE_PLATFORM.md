# Manage Platform Guide

This guide covers day-to-day operations: building workloads, submitting jobs, monitoring, scaling, and troubleshooting the production platform.

---

## Prerequisites

Before using this guide, ensure:

1. **Infrastructure is deployed**: See [LAUNCH_PLATFORM.md](LAUNCH_PLATFORM.md)
2. **kubectl is connected**:
   ```bash
   gcloud container clusters get-credentials ml-platform-gke \
     --region $REGION --project $PROJECT_ID
   ```
3. **Docker is configured for Artifact Registry**:
   ```bash
   gcloud auth configure-docker ${REGION}-docker.pkg.dev
   ```

---

## Platform CLI Reference

The `platform` CLI simplifies common operations:

| Command | Description |
|---------|-------------|
| `platform status` | Show cluster health and job summary |
| `platform build <workload> <version>` | Build and push container to Artifact Registry |
| `platform submit <workload>:<version>` | Submit training job to GKE |
| `platform logs <job-name>` | View job logs (streaming) |
| `platform list` | List all jobs |
| `platform scale <replicas>` | Scale Ray workers |
| `platform port-forward [service]` | Access dashboards locally |

---

## Building Workloads

### Build and Push Container

```bash
# Build from docs/examples/stellar_optimization
platform build stellar_optimization v1.0.0
```

This command:
1. Configures Docker for Artifact Registry
2. Builds the Docker image from `docs/examples/<workload>/Dockerfile`
3. Pushes to `${REGION}-docker.pkg.dev/${PROJECT_ID}/ml-platform/<workload>:<version>`
4. Also pushes with `latest` tag

### Build Custom Workload

```bash
# Create your workload directory
mkdir -p docs/examples/my_workload
cp docs/examples/stellar_optimization/* docs/examples/my_workload/

# Edit your training code
vim docs/examples/my_workload/train.py

# Build and push
platform build my_workload v1.0.0
```

### Manual Docker Build

For more control over the build process:

```bash
cd docs/examples/my_workload

# Build locally
docker build -t my_workload:local .

# Tag for registry
docker tag my_workload:local \
  europe-west3-docker.pkg.dev/${PROJECT_ID}/ml-platform/my_workload:v1.0.0

# Push
docker push europe-west3-docker.pkg.dev/${PROJECT_ID}/ml-platform/my_workload:v1.0.0
```

---

## Submitting Jobs

### Submit Training Job

```bash
platform submit stellar_optimization:v1.0.0
```

Output:
```
🚀 Submitting: stellar_optimization-20251202-143022
   Image: europe-west3-docker.pkg.dev/project-id/ml-platform/stellar_optimization:v1.0.0
   TTL: 86400s (auto-cleanup after completion)

✅ Job submitted: stellar_optimization-20251202-143022

Monitor with:
  ml-platform logs stellar_optimization-20251202-143022
```

### Submit with Custom TTL

Jobs auto-delete after completion. Adjust the TTL (time-to-live):

```bash
# Keep completed job for 1 hour
platform submit stellar_optimization:v1.0.0 --ttl=3600

# Keep completed job for 7 days
platform submit stellar_optimization:v1.0.0 --ttl=604800
```

### Submit with kubectl (Advanced)

For custom job configurations:

```yaml
# my-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: custom-training-job
  namespace: jobs
spec:
  ttlSecondsAfterFinished: 86400
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: job-runner
      containers:
      - name: worker
        image: europe-west3-docker.pkg.dev/PROJECT/ml-platform/workload:v1
        env:
        - name: RAY_ADDRESS
          value: "ray://ray-cluster-head-svc.ray-system.svc.cluster.local:10001"
        - name: GCS_BUCKET
          value: "gs://PROJECT-ml-artifacts"
        - name: CUSTOM_VAR
          value: "custom-value"
        resources:
          requests:
            cpu: "8"
            memory: "32Gi"
          limits:
            cpu: "16"
            memory: "64Gi"
```

```bash
kubectl apply -f my-job.yaml
```

---

## Monitoring Jobs

### View Job Logs

```bash
# Stream logs from running job
platform logs stellar_optimization-20251202-143022

# With kubectl (more options)
kubectl logs -n jobs job/stellar_optimization-20251202-143022 -f

# Get logs from specific pod
kubectl logs -n jobs POD_NAME

# Get previous container logs (if crashed)
kubectl logs -n jobs POD_NAME --previous
```

### List All Jobs

```bash
platform list
```

Output:
```
📦 Jobs:

NAME                                    COMPLETIONS   DURATION   AGE
stellar_optimization-20251202-143022    1/1           5m32s      10m
my_workload-20251202-140000             0/1           15m        15m
```

### Check Job Status

```bash
# Quick status
platform status

# Detailed job info
kubectl describe job -n jobs stellar_optimization-20251202-143022

# Pod status
kubectl get pods -n jobs

# Pod details
kubectl describe pod -n jobs POD_NAME

# Cluster events
kubectl get events -n jobs --sort-by='.lastTimestamp'
```

---

## Accessing Dashboards

### Port-Forward All Dashboards

```bash
platform port-forward all
```

Opens:
- Ray Dashboard: http://localhost:8265
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

Press `Ctrl+C` to stop.

### Port-Forward Individual Services

```bash
# Ray Dashboard
platform port-forward ray

# Grafana
platform port-forward grafana

# Prometheus
platform port-forward prometheus
```

### Ray Dashboard Features

The Ray Dashboard (http://localhost:8265) shows:
- **Cluster Overview**: Node status, resources
- **Jobs**: Running and completed Ray jobs
- **Actors**: Active Ray actors
- **Metrics**: CPU, memory, GPU utilization
- **Logs**: Aggregated worker logs

### Grafana Dashboards

Pre-configured dashboards include:
- Kubernetes cluster overview
- Node resource utilization
- Pod metrics
- Ray cluster metrics

---

## Scaling

### Scale Ray Workers

```bash
# Scale up for more parallelism
platform scale 10

# Scale down to save costs
platform scale 2

# Scale to zero (stops all workers)
platform scale 0
```

### Check Current Scale

```bash
kubectl get pods -n ray-system
```

### Auto-Scaling Behavior

The Ray cluster auto-scales based on workload:
- **Min replicas**: 1 (or 0 if configured)
- **Max replicas**: 10 (configurable in Terraform)
- **Scale-up**: When pending tasks exceed available resources
- **Scale-down**: When workers are idle for 5+ minutes

### Manual Node Pool Scaling

For more compute capacity, scale the GKE node pool:

```bash
# Scale node pool directly
gcloud container clusters resize ml-platform-gke \
  --region $REGION \
  --node-pool cpu-pool \
  --num-nodes 5

# Or update Terraform and apply
# terraform/envs/dev/terraform.tfvars
# cpu_max_nodes = 20
terraform apply
```

---

## Storage

### Access GCS Bucket

Jobs automatically have access to the ML artifacts bucket:

```bash
# List bucket contents
gsutil ls gs://${PROJECT_ID}-ml-artifacts/

# Download results
gsutil -m cp -r gs://${PROJECT_ID}-ml-artifacts/results/ ./local_results/

# Upload data
gsutil -m cp -r ./data/ gs://${PROJECT_ID}-ml-artifacts/input/
```

### Using Storage in Code

```python
from google.cloud import storage

# Upload results
client = storage.Client()
bucket = client.bucket(f"{os.environ['PROJECT_ID']}-ml-artifacts")
blob = bucket.blob("results/model.pkl")
blob.upload_from_filename("model.pkl")

# Download data
blob = bucket.blob("input/data.csv")
blob.download_to_filename("data.csv")
```

---

## Managing Resources

### View Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n jobs
kubectl top pods -n ray-system

# Detailed node info
kubectl describe nodes
```

### Resource Quotas

Jobs namespace has quotas to prevent runaway costs:

```bash
# View quotas
kubectl describe resourcequota -n jobs
```

Default limits:
- CPU requests: 100 cores
- Memory requests: 400Gi
- Max pods: 100
- Max jobs: 50

### Delete Jobs

```bash
# Delete specific job
kubectl delete job -n jobs stellar_optimization-20251202-143022

# Delete all completed jobs
kubectl delete jobs -n jobs --field-selector status.successful=1

# Delete all jobs (caution!)
kubectl delete jobs -n jobs --all
```

---

## Troubleshooting

### Job Not Starting

```bash
# Check job status
kubectl describe job -n jobs JOB_NAME

# Check pod status
kubectl get pods -n jobs
kubectl describe pod -n jobs POD_NAME

# Common issues in events
kubectl get events -n jobs --sort-by='.lastTimestamp'
```

**Common Issues:**

| Status | Cause | Fix |
|--------|-------|-----|
| `ImagePullBackOff` | Image doesn't exist | Rebuild: `platform build workload v1` |
| `Pending` | Insufficient resources | Scale up or reduce requests |
| `CrashLoopBackOff` | Code error | Check logs: `platform logs JOB` |
| `ErrImagePull` | Auth issue | Run: `gcloud auth configure-docker` |

### Ray Connection Issues

```bash
# Check Ray cluster
kubectl get pods -n ray-system

# Check Ray head logs
kubectl logs -n ray-system -l ray.io/node-type=head

# Check Ray worker logs
kubectl logs -n ray-system -l ray.io/node-type=worker

# Restart Ray cluster
kubectl delete raycluster ray-cluster -n ray-system
# Wait for KubeRay to recreate it
kubectl get pods -n ray-system -w
```

### Out of Memory

```bash
# Check if pod was OOMKilled
kubectl describe pod -n jobs POD_NAME | grep -A5 "State:"

# Solutions:
# 1. Increase memory in job manifest
# 2. Optimize your code
# 3. Use larger machine types (update Terraform)
```

### Network Issues

```bash
# Test connectivity from a job pod
kubectl exec -it -n jobs POD_NAME -- /bin/bash

# Inside the pod:
curl ray-cluster-head-svc.ray-system.svc.cluster.local:8265
curl storage.googleapis.com
```

### Monitoring Stack Issues

```bash
# Check Prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check Grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Restart monitoring
kubectl rollout restart deployment -n monitoring prometheus-grafana
```

---

## Best Practices

### Job Design

1. **Set appropriate resource requests**: Match actual usage to avoid waste
2. **Use TTL for cleanup**: Set `--ttl` to auto-delete completed jobs
3. **Handle failures gracefully**: Use `backoffLimit` for retries
4. **Log progress**: Print checkpoints for debugging
5. **Save intermediate results**: Checkpoint to GCS for long-running jobs

### Cost Control

1. **Scale down when idle**: `platform scale 0` outside work hours
2. **Use preemptible VMs**: Enabled by default, 60-80% cheaper
3. **Set node pool limits**: Prevent unbounded scaling
4. **Monitor spending**: Check GCP billing dashboard
5. **Clean up old jobs**: Delete completed jobs and images

### Security

1. **Use Workload Identity**: Automatic with this setup (no key files)
2. **Rotate secrets**: Change Grafana password periodically
3. **Limit network access**: Network policies are enabled
4. **Review RBAC**: Job runners have minimal permissions

---

## Quick Reference

```bash
# === Status ===
platform status                    # Overall health
kubectl get nodes                  # Node status
kubectl get pods -A                # All pods

# === Jobs ===
platform build workload v1         # Build container
platform submit workload:v1        # Submit job
platform list                      # List jobs
platform logs JOB_NAME             # View logs

# === Scaling ===
platform scale N                   # Scale Ray workers

# === Dashboards ===
platform port-forward all          # All dashboards
platform port-forward ray          # Ray: localhost:8265
platform port-forward grafana      # Grafana: localhost:3000

# === Cleanup ===
kubectl delete job -n jobs NAME    # Delete job
kubectl delete jobs -n jobs --all  # Delete all jobs
```

---

## Next Steps

- **Develop workloads**: See [DEV_GUIDE.md](DEV_GUIDE.md)
- **Infrastructure changes**: See [LAUNCH_PLATFORM.md](LAUNCH_PLATFORM.md)
- **CI/CD setup**: See [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)
- **Example workloads**: See [examples/stellar_optimization/README.md](examples/stellar_optimization/README.md)
