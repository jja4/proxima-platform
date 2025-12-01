"""Submit command - submit training jobs"""

import subprocess
import sys
from datetime import datetime


# Default TTL for completed jobs (24 hours)
DEFAULT_TTL_SECONDS = 86400


def run_cmd(cmd: str) -> tuple:
    """Run shell command and return output"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip(), result.returncode


def run(args):
    """Submit a training job"""
    if len(args) < 1:
        print("Usage: platform submit <workload>:<version> [--ttl=SECONDS]")
        print("Example: platform submit stellar_optimization:v1.0.0")
        print("         platform submit stellar_optimization:v1.0.0 --ttl=3600")
        sys.exit(1)
    
    workload_version = args[0]
    
    # Parse optional TTL argument
    ttl_seconds = DEFAULT_TTL_SECONDS
    for arg in args[1:]:
        if arg.startswith("--ttl="):
            try:
                ttl_seconds = int(arg.split("=")[1])
            except ValueError:
                print(f"❌ Invalid TTL value: {arg}")
                sys.exit(1)
    
    if ':' not in workload_version:
        print("❌ Format: workload:version (e.g., stellar_optimization:v1.0.0)")
        sys.exit(1)
    
    workload, version = workload_version.split(':', 1)
    
    # Get project ID
    project_id, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        print("❌ No GCP project configured. Run: gcloud config set project PROJECT_ID")
        sys.exit(1)
    
    region = "us-central1"
    image = f"{region}-docker.pkg.dev/{project_id}/ml-platform-ml/{workload}:{version}"
    job_name = f"{workload}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    
    print(f"🚀 Submitting: {job_name}")
    print(f"   Image: {image}")
    print(f"   TTL: {ttl_seconds}s (auto-cleanup after completion)\n")
    
    manifest = f"""
apiVersion: batch/v1
kind: Job
metadata:
  name: {job_name}
  namespace: jobs
  labels:
    app: {workload}
spec:
  ttlSecondsAfterFinished: {ttl_seconds}
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: job-runner
      containers:
      - name: worker
        image: {image}
        env:
        - name: RAY_ADDRESS
          value: "ray://ray-cluster-head-svc.ray-system.svc.cluster.local:10001"
        - name: GCS_BUCKET
          value: "gs://{project_id}-ml-artifacts"
        resources:
          requests:
            cpu: "4"
            memory: "16Gi"
          limits:
            cpu: "8"
            memory: "32Gi"
"""
    
    result = subprocess.run(
        ["kubectl", "apply", "-f", "-"],
        input=manifest,
        text=True,
        capture_output=True
    )
    
    if result.returncode == 0:
        print(f"✅ Job submitted: {job_name}\n")
        print("Monitor with:")
        print(f"  platform logs {job_name}")
    else:
        print(f"❌ Error: {result.stderr}")
        sys.exit(1)
