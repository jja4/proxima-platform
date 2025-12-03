"""
Distributed Stellarator Optimization

This example demonstrates running distributed stellarator optimization
using Ray and the Constellaration physics library.

## What This Does

Optimizes stellarator magnetic configurations in parallel using:
- Ray for distributed computing across multiple workers
- Constellaration library for physics calculations (VMEC, DESC)
- Google Cloud Storage for saving results

## Quick Start

```bash
# Build container
python -m ml_platform.cli build stellar_optimization v1.0.0

# Submit training job
python -m ml_platform.cli submit stellar_optimization:v1.0.0

# Monitor progress
python -m ml_platform.cli logs stellar-optimization-TIMESTAMP
```

## Files in This Example

- `train.py` - Main training script with Ray parallelization
- `Dockerfile` - Container image definition
- `requirements.txt` - Python dependencies
- `job.yaml` - Kubernetes job manifest (optional, CLI does this automatically)

## The Training Code

See `train.py` for the complete implementation. Key points:

```python
import ray
from constellaration.problems import StellaratorProblem

# Connect to Ray cluster
ray.init(address="auto")

@ray.remote
def optimize_config(config_params):
    problem = StellaratorProblem(config_params)
    result = problem.optimize()
    return result

# Run distributed optimization
configs = generate_configurations(num=100)
futures = [optimize_config.remote(c) for c in configs]
results = ray.get(futures)  # Runs in parallel!

# Save best result
best = max(results, key=lambda r: r.score)
save_to_gcs(best)
```

## Running Locally (for testing)

```bash
# Start local Ray cluster
ray start --head

# Run training script
cd examples/stellar_optimization
python train.py --num-configs 10

# Stop Ray
ray stop
```

## Configuration

Edit `train.py` to adjust:

```python
# Number of configurations to try
NUM_CONFIGS = 100

# Optimization parameters
OPTIMIZATION_PARAMS = {
    "max_iter": 1000,
    "convergence_tol": 1e-6,
}

# Output location
OUTPUT_BUCKET = "gs://PROJECT-ml-artifacts/stellar_opt/"
```

## Resource Requirements

Edit `job.yaml` to adjust compute resources:

```yaml
resources:
  requests:
    cpu: "8"        # 8 CPUs per worker
    memory: "32Gi"  # 32GB RAM
  limits:
    cpu: "16"
    memory: "64Gi"
```

For GPU support:
```yaml
resources:
  limits:
    nvidia.com/gpu: 1  # Request 1 GPU
```

## Monitoring

### View Ray Dashboard

```bash
python -m ml_platform.cli port-forward ray
# Open http://localhost:8265
```

You'll see:
- Active workers and their resource usage
- Running tasks and their progress
- Task timeline and execution trace
- Cluster metrics (CPU, memory, network)

### Check Job Status

```bash
# List all jobs
python -m ml_platform.cli list

# Get detailed status
kubectl describe job stellar-optimization-TIMESTAMP -n jobs

# View events
kubectl get events -n jobs
```

### View Logs

```bash
# Follow logs in real-time
python -m ml_platform.cli logs stellar-optimization-TIMESTAMP

# Or with kubectl
kubectl logs -n jobs job/stellar-optimization-TIMESTAMP -f
```

## Results

Results are automatically saved to Google Cloud Storage:

```
gs://PROJECT-ml-artifacts/stellar_optimization/TIMESTAMP/
├── best_config.json      # Best configuration found
├── all_results.pkl       # All optimization results
├── metrics.json          # Performance metrics
└── plots/                # Visualization plots
    ├── convergence.png
    └── magnetic_field.png
```

To download results:
```bash
gsutil -m cp -r gs://PROJECT-ml-artifacts/stellar_optimization/TIMESTAMP ./results/
```

## Hyperparameter Tuning

To run a hyperparameter sweep, edit `train.py`:

```python
# Define parameter grid
param_grid = {
    "max_iter": [500, 1000, 2000],
    "learning_rate": [0.001, 0.01, 0.1],
    "batch_size": [16, 32, 64],
}

# Run distributed sweep
@ray.remote
def train_with_params(params):
    problem = StellaratorProblem(**params)
    return problem.optimize()

# Try all combinations in parallel
from itertools import product
configs = [dict(zip(param_grid.keys(), v)) 
           for v in product(*param_grid.values())]
results = ray.get([train_with_params.remote(c) for c in configs])
```

## Scaling

### Scale Ray Workers

```bash
# Scale up for more parallelism
python -m ml_platform.cli scale 20

# Scale down to save costs
python -m ml_platform.cli scale 2
```

### Auto-scaling

The Ray cluster auto-scales between 1-10 workers by default.
To adjust, edit `kubernetes/ray/ray-cluster.yaml`:

```yaml
workerGroupSpecs:
- replicas: 5        # Initial workers
  minReplicas: 1     # Minimum (scale to zero saves costs)
  maxReplicas: 20    # Maximum
```

## Troubleshooting

### Job Not Starting

```bash
# Check job status
kubectl describe job stellar-optimization-TIMESTAMP -n jobs

# Check pod status
kubectl get pods -n jobs
kubectl describe pod POD_NAME -n jobs
```

Common issues:
- **ImagePullBackOff**: Image doesn't exist or wrong name
- **Pending**: Not enough cluster resources
- **CrashLoopBackOff**: Error in training code

### Out of Memory

Increase memory limits in `job.yaml`:
```yaml
resources:
  requests:
    memory: "64Gi"  # Increase this
```

Or scale up to larger nodes:
```bash
# Edit terraform/envs/dev/terraform.tfvars
cpu_machine_type = "n2-standard-32"  # More RAM
```

### Ray Connection Issues

```bash
# Check Ray cluster
kubectl get pods -n ray-system

# Check Ray head logs
kubectl logs -n ray-system -l ray.io/node-type=head

# Restart Ray cluster
kubectl delete raycluster ray-cluster -n ray-system
kubectl apply -f kubernetes/ray/ray-cluster.yaml
```

## Creating Your Own Workload

Use this as a template:

```bash
# Copy this example
cp -r examples/stellar_optimization examples/my_workload

# Edit training code
vim examples/my_workload/train.py

# Update Dockerfile if needed
vim examples/my_workload/Dockerfile

# Build and run
python -m ml_platform.cli build my_workload v1.0.0
python -m ml_platform.cli submit my_workload:v1.0.0
```

## Performance Tips

1. **Batch work appropriately**: Don't make tasks too small (overhead) or too large (poor load balancing)
2. **Use object store**: For large data, use `ray.put()` to avoid serialization overhead
3. **Monitor Ray dashboard**: Watch for stragglers and bottlenecks
4. **Profile your code**: Use `ray.timeline()` to see where time is spent
5. **Resource requests**: Set accurate CPU/memory requests to avoid OOM kills

## Next Steps

- Read the [Platform Documentation](../../README.md)
- Check out the [Developer Guide](../../README.md#documentation)
- Try running locally first before deploying to cluster
- Start small (few configs) then scale up
- Monitor costs in GCP Console

## Questions?

- Ray documentation: https://docs.ray.io
- Constellaration repo: https://github.com/proximafusion/constellaration
- Platform issues: GitHub Issues
