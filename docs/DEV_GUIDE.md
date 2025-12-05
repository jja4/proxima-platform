# Developer Guide

This guide covers everything you need to develop and test your ML workloads locally before deploying to production.

---

## Dev Container Setup

The dev container is your **unified development environment** with all tools pre-installed:

- **Python 3.10** with `uv` package manager
- **Ray** for distributed computing (local cluster)
- **kubectl, helm, terraform, gcloud** CLI tools
- **Docker** access (build containers from inside)
- **MinIO** for local S3-compatible storage
- **Prometheus + Grafana** for monitoring

### Prerequisites

- [VS Code](https://code.visualstudio.com/) with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) running

### Opening the Dev Container

1. Clone this repository
2. Open in VS Code
3. Click **"Reopen in Container"** when prompted  
   (or press `Cmd+Shift+P` → "Dev Containers: Reopen in Container")
4. Wait ~2 minutes for setup

When ready, you'll see:
```
✅ Platform ready! Ray cluster, MinIO, and monitoring are running.
   Ray Dashboard: http://localhost:8265
   MinIO Console: http://localhost:9001
   Grafana:       http://localhost:3000
```

---

## Local Services

The dev container automatically starts these services:

| Service | URL | Purpose | Credentials |
|---------|-----|---------|-------------|
| Ray Dashboard | http://localhost:8265 | Monitor distributed tasks | - |
| MinIO Console | http://localhost:9001 | S3-compatible storage | minioadmin / minioadmin |
| MinIO API | http://localhost:9000 | Storage API endpoint | minioadmin / minioadmin |
| Grafana | http://localhost:3000 | Metrics dashboards | admin / admin |
| Prometheus | http://localhost:9090 | Metrics backend | - |

### Restarting Local Services

```bash
# View service logs
docker compose -f .devcontainer/docker-compose.yml logs ray-head

# Restart all services
docker compose -f .devcontainer/docker-compose.yml restart

# Restart specific service
docker compose -f .devcontainer/docker-compose.yml restart ray-head
```

---

## Running Code Locally

### Run Python Scripts Directly

```bash
# Run example training job
python docs/examples/stellar_optimization/train.py

# Run with arguments
python docs/examples/stellar_optimization/train.py --num-configs 10
```

### Connect to Ray Programmatically

```python
import ray

# Connect to local Ray cluster
ray.init("ray://localhost:10001")

# Check available resources
print(ray.cluster_resources())

# Run distributed tasks
@ray.remote
def my_task(x):
    return x * 2

results = ray.get([my_task.remote(i) for i in range(10)])
print(results)
```

---

## Creating Your Own Workload

### Step 1: Copy the Template

```bash
cp -r docs/examples/stellar_optimization docs/examples/my_experiment
```

### Step 2: Edit Your Training Code

```bash
code docs/examples/my_experiment/train.py
```

Example training script structure:
```python
import ray
import os

def main():
    # Connect to Ray (works locally and on GKE)
    ray.init(address=os.environ.get("RAY_ADDRESS", "ray://localhost:10001"))
    
    @ray.remote
    def train_config(config):
        # Your training logic here
        return {"config": config, "score": 0.95}
    
    # Run distributed training
    configs = [{"lr": 0.01}, {"lr": 0.001}]
    futures = [train_config.remote(c) for c in configs]
    results = ray.get(futures)
    
    # Save results
    best = max(results, key=lambda r: r["score"])
    print(f"Best result: {best}")

if __name__ == "__main__":
    main()
```

### Step 3: Update the Dockerfile

Edit `docs/examples/my_experiment/Dockerfile`:
```dockerfile
FROM rayproject/ray-ml:2.9.0-py310

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy training code
COPY train.py .

# Run training
CMD ["python", "train.py"]
```

### Step 4: Update Requirements

Edit `docs/examples/my_experiment/requirements.txt`:
```
numpy>=1.24.0
pandas>=2.0.0
# Add your dependencies
```

### Step 5: Test Locally

```bash
# Run directly
python docs/examples/my_experiment/train.py

# Or build and run container locally
cd docs/examples/my_experiment
docker build -t my_experiment:local .
docker run --network host my_experiment:local
```

---

## Dependency Management

This project uses **[UV](https://github.com/astral-sh/uv)** for fast Python package management.

### Install Dependencies

```bash
# Install all dependencies (done automatically in dev container)
uv sync

# Install with dev tools (pytest, black, ruff)
uv sync --extra dev

# Install with example dependencies
uv sync --extra examples
```

### Add New Dependencies

```bash
# Add runtime dependency
uv add google-cloud-storage

# Add dev-only dependency
uv add --dev pytest

# Update lock file
uv lock --upgrade
```

### Remove Dependencies

```bash
uv remove package-name
```

---

## Project Structure

```
proxima-platform/
├── .devcontainer/          # Dev container configuration
│   ├── devcontainer.json   # VS Code settings, extensions, ports
│   ├── docker-compose.yml  # Local Ray, MinIO, monitoring services
│   └── Dockerfile          # Dev container image
├── ml-platform/
│   ├── bin/ml-platform        # CLI executable
│   ├── cli/                # CLI implementation
│   │   ├── main.py         # Command dispatcher
│   │   └── commands/       # Individual commands
│   └── sdk/                # Python SDK for programmatic use
├── docs/
│   ├── examples/           # Example workloads (copy these!)
│   │   └── stellar_optimization/
│   ├── DEV_GUIDE.md        # This file
│   ├── LAUNCH_PLATFORM.md  # Infrastructure deployment
│   └── USE_PLATFORM.md  # Operations guide
├── terraform/              # Infrastructure as Code
├── kubernetes/             # K8s manifests
└── pyproject.toml          # Python project config
```

---

## Testing

### Run Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=platform

# Run specific test file
pytest tests/test_cli.py
```

### Code Quality

```bash
# Format code
black ml-platform/ tests/

# Lint code
ruff check ml-platform/ tests/

# Type checking
mypy ml-platform/
```

---

## Local vs Production

| Aspect | Local (Dev Container) | Production (GKE) |
|--------|----------------------|------------------|
| Start training | `python train.py` | `platform submit workload:v1` |
| Storage | MinIO (localhost:9000) | Google Cloud Storage |
| Compute | Docker containers (2 workers) | Kubernetes pods (autoscaling) |
| GPUs | Not available | NVIDIA T4/A100 |
| Cost | Free | Pay for GCP resources |
| Use case | Development, testing | Production, large-scale |

---

## Troubleshooting

### Ray Not Connecting

```bash
# Check Ray services
docker compose -f .devcontainer/docker-compose.yml logs ray-head
docker compose -f .devcontainer/docker-compose.yml logs ray-worker

# Restart Ray cluster
docker compose -f .devcontainer/docker-compose.yml restart ray-head ray-worker
```

### ml-platform Command Not Found

```bash
# Activate virtual environment
source .venv/bin/activate

# Reinstall
uv sync
```

### UV Not Found

```bash
# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add to PATH
export PATH="$HOME/.cargo/bin:$PATH"
```

### Container Build Fails

```bash
# Check Docker is running
docker info

# Clear Docker cache
docker system prune -a
```

---

## Next Steps

Once your workload runs successfully locally:

1. **Deploy infrastructure**: See [LAUNCH_PLATFORM.md](LAUNCH_PLATFORM.md)
2. **Submit to production**: See [USE_PLATFORM.md](USE_PLATFORM.md)
3. **Review example workloads**: See [examples/stellar_optimization/README.md](examples/stellar_optimization/README.md)
