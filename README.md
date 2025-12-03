# Constellaration ML Training Platform

Production-grade platform for distributed ML training on GCP with Kubernetes and Ray.

## 🚀 Quick Start

### Open in Dev Container (Recommended)

The dev container is your complete development environment with all tools pre-installed.

```bash
# 1. Open repo in VS Code
# 2. Click "Reopen in Container" when prompted
# 3. Everything is ready - local Ray cluster, monitoring, CLI tools
```

**From inside the dev container, you can:**

```bash
# LOCAL: Test training code (no GCP needed)
python docs/examples/stellar_optimization/train.py

# PRODUCTION: Deploy to GKE and submit jobs
gcloud auth login
cd terraform/envs/dev && terraform apply
ml-platform submit stellar_optimization:v1.0.0
```

See **[docs/QUICKSTART.md](docs/QUICKSTART.md)** for complete setup guide.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Google Cloud Platform                                      │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  GKE Cluster                                         │   │
│  │                                                      │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │   │
│  │  │ Ray Head    │  │ Ray Workers │  │ Monitoring   │. │   │
│  │  │ (Dashboard) │  │ (CPU/GPU)   │  │ (Prom/Graf)  │. │   │
│  │  └─────────────┘  └─────────────┘  └──────────────┘  │   │
│  │                                                      │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │  Training Jobs (K8s Jobs)                       │ │   │
│  │  │  - Stellarator Optimization                     │ │   │
│  │  │  - Hyperparameter Tuning                        │ │   │
│  │  │  - Data Processing                              │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐    │
│  │ Artifact     │  │ Cloud        │  │ Cloud           │    │
│  │ Registry     │  │ Storage      │  │ Logging         │    │
│  └──────────────┘  └──────────────┘  └─────────────────┘    │ 
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
proxima-platform/
├── .devcontainer/          # 🐳 VS Code dev container config
│   ├── devcontainer.json   # Container settings, tools, extensions
│   └── Dockerfile          # Container image
├── ml-platform/
│   ├── bin/
│   │   └── ml-platform        # 🎯 Executable CLI script
│   ├── cli/                # CLI implementation
│   │   ├── main.py         # Command dispatcher
│   │   └── commands/       # Each command in its own module
│   │       ├── status.py
│   │       ├── submit.py
│   │       ├── build.py
│   │       ├── logs.py
│   │       ├── scale.py
│   │       ├── port_forward.py
│   │       └── list_jobs.py
│   └── sdk/                # SDK for programmatic use
│       └── core/           # Core SDK classes
│           ├── client.py   # PlatformClient
│           └── job.py      # Job class
├── docs/
│   ├── examples/           # 📚 Example workloads with documentation
│   │   └── stellar_optimization/
│   │       ├── README.md   # Complete guide
│   │       ├── train.py    # Training code
│   │       ├── Dockerfile  # Container definition
│   │       └── job.yaml    # Kubernetes manifest
│   ├── QUICKSTART.md       # Getting started guide
│   └── GITHUB_ACTIONS.md   # CI/CD setup
├── terraform/              # Infrastructure as Code
├── kubernetes/             # Kubernetes manifests
├── pyproject.toml          # Project config (dependencies, build)
└── uv.lock                 # Lock file (reproducible installs)
```

## 🎯 Why This Structure?

### ✅ Modern Python Packaging
- `pyproject.toml` - All config in one place
- `uv sync` - Fast, reproducible installs with lock file
- `uv add` - Easy dependency management

### ✅ Clean Executable
```bash
ml-platform status              # Clean! ✨
# vs
python -m ml_platform.cli status  # Verbose 😕
```

### ✅ Fast Package Management (UV)
```bash
uv sync                      # 10-100x faster than pip! ⚡
uv add package-name          # Add dependency to pyproject.toml
```

## 🛠 Installation

### Option 1: Modern UV Workflow (Recommended)
```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
# Or: brew install uv

# Install ml-platform (creates .venv, installs CLI)
uv sync

# Activate virtual environment
source .venv/bin/activate  # macOS/Linux
.venv\Scripts\activate     # Windows

# Now 'ml-platform' command is available
ml-platform status

# With dev tools (pytest, black, ruff)
uv sync --extra dev

# With example dependencies (to run stellar_optimization)
uv sync --extra examples
```

### Option 2: Legacy pip-compatible
```bash
pip install -e .
ml-platform status
```

### Option 3: Add bin/ to PATH (no venv)
```bash
export PATH="$PWD/platform/bin:$PATH"
ml-platform status
```

### Option 4: Dev Container (VS Code)
```bash
# Open in VS Code
code .

# Click "Reopen in Container"
# Container auto-runs: uv sync --extra dev
# Virtual env is auto-activated!

ml-platform status  # ✅ Just works!
```

## 🎮 CLI Commands (GKE Production)

> **Note:** These commands require a deployed GKE cluster. For local development, run Python scripts directly.

```bash
ml-platform status                           # Show ml-platform health
ml-platform build <workload> <version>       # Build and push container
ml-platform submit <workload>:<version>      # Submit training job
ml-platform logs <job-name>                  # View job logs
ml-platform list                             # List all jobs
ml-platform scale <replicas>                 # Scale Ray workers
ml-platform port-forward [ray|grafana|all]   # Access dashboards
```

### Examples

```bash
# Build workload
ml-platform build stellar_optimization v1.0.0

# Submit job
ml-platform submit stellar_optimization:v1.0.0

# Monitor
ml-platform logs stellar-optimization-20251201-120000

# Scale Ray cluster
ml-platform scale 20

# Access dashboards
ml-platform port-forward ray      # Ray: http://localhost:8265
ml-platform port-forward grafana  # Grafana: http://localhost:3000
ml-platform port-forward all      # All dashboards
```

## 🐍 SDK Usage

```python
from ml_platform.sdk import PlatformClient

# Create client
client = PlatformClient(project_id="your-project")

# Submit job
job = client.submit_job(
    name="training",
    image="europe-west3-docker.pkg.dev/project/repo/model:v1",
    cpu="8",
    memory="32Gi",
    env={"LEARNING_RATE": "0.001"}
)

# Monitor
print(job.status())
job.wait(timeout=3600)
print(job.logs())

# Scale platform
client.scale_ray(replicas=20)
```

## 📦 Dependency Management

### Add Dependencies
```bash
# Add runtime dependency
uv add google-cloud-storage

# Add dev dependency
uv add --dev pytest

# Install/update everything
uv sync
```

### Lock Dependencies
```bash
# Update lock file
uv lock --upgrade

# Sync to lock file
uv sync
```

### Remove Dependencies
```bash
uv remove package-name
```

## 🐳 Dev Container (VS Code)

### What is a Dev Container?

A Docker container with **everything pre-installed**:
- Python 3.10 + UV
- kubectl, helm, terraform, gcloud
- Docker
- VS Code extensions

### Why Use It?

✅ **Consistent environment** - Same tools/versions for everyone
✅ **No local setup** - Everything in container
✅ **Fast** - Uses UV for quick installs
✅ **Pre-configured** - Ready to code immediately

### How to Use

```bash
# 1. Open in VS Code
code .

# 2. Click "Reopen in Container"
#    Container automatically runs: uv sync --extra dev

# 3. Terminal opens with activated venv
ml-platform status    # ✅ Works!
kubectl get nodes  # ✅ Works!
uv add requests    # ✅ Works!
```

## 🚢 Deployment

```bash
# 1. Deploy infrastructure
cd terraform/envs/dev
terraform init
terraform apply -var="project_id=YOUR_PROJECT"

# 2. Connect to cluster
gcloud container clusters get-credentials ml-platform-gke \
  --region europe-west3 --project YOUR_PROJECT

# 3. Verify
ml-platform status
```

## 📚 Documentation

- **[Quick Start](docs/QUICKSTART.md)** - 5-minute overview
- **[Developer Guide](docs/DEV_GUIDE.md)** - Local development & testing
- **[Launch Platform](docs/LAUNCH_PLATFORM.md)** - Terraform deployment & GCP setup
- **[Manage Platform](docs/USE_PLATFORM.md)** - Operations, monitoring, scaling
- **[GitHub Actions Setup](docs/GITHUB_ACTIONS.md)** - CI/CD configuration
- **[Example: Stellar Optimization](docs/examples/stellar_optimization/README.md)** - Full example workload

## 🎓 Creating Your Own Workload

```bash
# 1. Copy example
cp -r docs/examples/stellar_optimization docs/examples/my_workload

# 2. Edit files
vim docs/examples/my_workload/train.py
vim docs/examples/my_workload/Dockerfile

# 3. Build & submit
ml-platform build my_workload v1.0.0
ml-platform submit my_workload:v1.0.0

# 4. Monitor
ml-platform logs my-workload-TIMESTAMP
```

## 📊 Monitoring

```bash
# Access dashboards
ml-platform port-forward ray       # localhost:8265
ml-platform port-forward grafana   # localhost:3000
ml-platform port-forward all       # All dashboards

# Job monitoring
ml-platform list
ml-platform logs job-name
ml-platform status
```

## 🆘 Troubleshooting

### ml-platform command not found
```bash
# Activate virtual environment
source .venv/bin/activate

# Or reinstall
uv sync
```

### UV not found
```bash
# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add to PATH
export PATH="$HOME/.cargo/bin:$PATH"
```

### Dependency conflicts
```bash
# Update and reinstall
uv lock --upgrade
uv sync
```

## ⚡ Why UV?

**UV is 10-100x faster than pip:**

```bash
# Speed comparison
time pip install ray[default]==2.9.0   # 45-60 seconds ⏱️
time uv add ray[default]==2.9.0        # 5-10 seconds ⚡
```

**Modern workflow:**
- `uv add package` - Add to pyproject.toml
- `uv sync` - Install from lock file (reproducible!)
- `uv lock --upgrade` - Update dependencies
- Auto-creates and manages virtual environments

**Benefits:**
- ✅ Written in Rust (fast!)
- ✅ Lock files for reproducible builds
- ✅ Smart caching across projects
- ✅ Better dependency resolution
- ✅ Modern UX

See **[docs/UV_GUIDE.md](docs/UV_GUIDE.md)** for complete guide.

## 🏗 Infrastructure

- **GCP**: GKE with autoscaling
- **Kubernetes**: Ray operator, monitoring
- **Ray**: Distributed computing
- **Monitoring**: Prometheus + Grafana
- **Storage**: Google Cloud Storage

## 📄 License

MIT

---

**Modern. Fast. Production-ready.** ⚡
