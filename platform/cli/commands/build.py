"""Build command - build and push containers"""

import subprocess
import sys
import os


def run_cmd(cmd: str) -> tuple:
    """Run shell command and return output"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip(), result.returncode


def run(args):
    """Build and push workload container"""
    if len(args) < 2:
        print("Usage: platform build <workload> <version>")
        print("Example: platform build stellar_optimization v1.0.0")
        print("\nAvailable workloads:")
        subprocess.run("ls -1 docs/examples/ 2>/dev/null || echo '  (none found)'", shell=True)
        sys.exit(1)
    
    workload = args[0]
    version = args[1]
    
    # Get project ID
    project_id, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        print("❌ No GCP project configured")
        print("Fix: gcloud config set project YOUR_PROJECT_ID")
        sys.exit(1)
    
    # Check workload exists
    workload_dir = f"docs/examples/{workload}"
    if not os.path.exists(workload_dir):
        print(f"❌ Workload not found: {workload_dir}")
        print("\nAvailable workloads:")
        subprocess.run("ls -1 docs/examples/", shell=True)
        sys.exit(1)
    
    if not os.path.exists(f"{workload_dir}/Dockerfile"):
        print(f"❌ No Dockerfile in {workload_dir}")
        sys.exit(1)
    
    region = "us-central1"
    image = f"{region}-docker.pkg.dev/{project_id}/ml-platform-ml/{workload}:{version}"
    image_latest = f"{region}-docker.pkg.dev/{project_id}/ml-platform-ml/{workload}:latest"
    
    print(f"🔨 Building: {workload}")
    print(f"📦 Version: {version}")
    print(f"🖼️  Image: {image}\n")
    
    # Configure Docker
    print("Configuring Docker...")
    subprocess.run(f"gcloud auth configure-docker {region}-docker.pkg.dev --quiet", shell=True)
    
    # Build
    print("\nBuilding container...")
    result = subprocess.run(
        f"docker build -t {image} -t {image_latest} {workload_dir}",
        shell=True
    )
    if result.returncode != 0:
        sys.exit(1)
    
    # Push
    print("\nPushing to registry...")
    result = subprocess.run(
        f"docker push {image} && docker push {image_latest}",
        shell=True
    )
    if result.returncode != 0:
        sys.exit(1)
    
    print(f"\n✅ Build complete!\n")
    print("Next steps:")
    print(f"  platform submit {workload}:{version}")
