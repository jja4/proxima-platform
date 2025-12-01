"""
Distributed Stellarator Optimization Training

This script demonstrates distributed optimization of stellarator configurations
using Ray for parallelization and the Constellaration library for physics.
"""

import ray
import os
import pickle
import json
from datetime import datetime
from pathlib import Path
from google.cloud import storage

# Uncomment when constellaration is available:
# from constellaration.problems import StellaratorProblem
# from constellaration.optimization import OptimizationResult


# Configuration
NUM_CONFIGS = int(os.getenv("NUM_CONFIGS", "50"))
MAX_ITER = int(os.getenv("MAX_ITER", "1000"))
GCS_BUCKET = os.getenv("GCS_BUCKET", "gs://PROJECT-ml-artifacts")
OUTPUT_PATH = f"stellar_optimization/{datetime.now().strftime('%Y%m%d-%H%M%S')}"


@ray.remote
def optimize_stellarator_config(config_id: int, params: dict):
    """
    Optimize a single stellarator configuration.
    
    This runs on a Ray worker and can execute in parallel with other configs.
    """
    print(f"⚙️  Worker {ray.get_runtime_context().get_worker_id()}: Optimizing config {config_id}")
    
    # TODO: Replace with actual constellaration code
    # problem = StellaratorProblem(
    #     geometry_params=params["geometry"],
    #     physics_params=params["physics"],
    # )
    # result = problem.optimize(max_iterations=MAX_ITER)
    
    # Placeholder result
    result = {
        "config_id": config_id,
        "score": 0.95,  # Replace with actual optimization score
        "converged": True,
        "iterations": 500,
        "final_params": params,
    }
    
    print(f"✅ Config {config_id} complete: score={result['score']:.4f}")
    return result


def generate_configurations(num: int):
    """Generate stellarator configurations to optimize"""
    print(f"📋 Generating {num} configurations...")
    
    configs = []
    for i in range(num):
        # TODO: Replace with actual parameter generation
        config = {
            "geometry": {
                "major_radius": 1.0 + i * 0.01,
                "minor_radius": 0.3,
                "n_field_periods": 5,
            },
            "physics": {
                "beta": 0.04,
                "aspect_ratio": 6.0,
            }
        }
        configs.append(config)
    
    return configs


def save_results_to_gcs(results: list, metrics: dict):
    """Save optimization results to Google Cloud Storage"""
    print(f"\n💾 Saving results to {GCS_BUCKET}/{OUTPUT_PATH}")
    
    # Parse bucket and path
    bucket_name = GCS_BUCKET.replace("gs://", "").split("/")[0]
    
    try:
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        
        # Save all results
        blob = bucket.blob(f"{OUTPUT_PATH}/all_results.pkl")
        blob.upload_from_string(pickle.dumps(results))
        print(f"  ✅ Saved all_results.pkl")
        
        # Save best config
        best = max(results, key=lambda r: r["score"])
        blob = bucket.blob(f"{OUTPUT_PATH}/best_config.json")
        blob.upload_from_string(json.dumps(best, indent=2))
        print(f"  ✅ Saved best_config.json (score: {best['score']:.4f})")
        
        # Save metrics
        blob = bucket.blob(f"{OUTPUT_PATH}/metrics.json")
        blob.upload_from_string(json.dumps(metrics, indent=2))
        print(f"  ✅ Saved metrics.json")
        
        print(f"\n📦 Results saved to: {GCS_BUCKET}/{OUTPUT_PATH}")
        
    except Exception as e:
        print(f"⚠️  Warning: Could not save to GCS: {e}")
        print("   Saving locally instead...")
        
        # Save locally as fallback
        Path("results").mkdir(exist_ok=True)
        with open("results/all_results.pkl", "wb") as f:
            pickle.dump(results, f)
        with open("results/best_config.json", "w") as f:
            json.dump(best, f, indent=2)
        with open("results/metrics.json", "w") as f:
            json.dump(metrics, f, indent=2)


def main():
    """Main training loop"""
    print("=" * 60)
    print("🚀 Stellarator Optimization Training")
    print("=" * 60)
    print(f"  Configurations: {NUM_CONFIGS}")
    print(f"  Max iterations: {MAX_ITER}")
    print(f"  Output: {GCS_BUCKET}/{OUTPUT_PATH}")
    print("=" * 60)
    print()
    
    # Connect to Ray cluster
    ray_address = os.getenv("RAY_ADDRESS", "auto")
    print(f"🔗 Connecting to Ray: {ray_address}")
    ray.init(address=ray_address)
    
    print(f"   Ray cluster resources:")
    print(f"     CPUs: {ray.cluster_resources().get('CPU', 0)}")
    print(f"     Memory: {ray.cluster_resources().get('memory', 0) / 1e9:.1f} GB")
    print(f"     Nodes: {len(ray.nodes())}")
    print()
    
    # Generate configurations
    configs = generate_configurations(NUM_CONFIGS)
    
    # Submit all optimization tasks to Ray
    print(f"🔄 Submitting {len(configs)} tasks to Ray cluster...")
    start_time = datetime.now()
    
    futures = [
        optimize_stellarator_config.remote(i, config)
        for i, config in enumerate(configs)
    ]
    
    # Wait for all results (executes in parallel!)
    print(f"⏳ Waiting for results...\n")
    results = ray.get(futures)
    
    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()
    
    # Calculate metrics
    print("\n" + "=" * 60)
    print("📊 Results Summary")
    print("=" * 60)
    
    converged = sum(1 for r in results if r["converged"])
    scores = [r["score"] for r in results]
    best_score = max(scores)
    avg_score = sum(scores) / len(scores)
    
    metrics = {
        "total_configs": len(results),
        "converged": converged,
        "best_score": best_score,
        "average_score": avg_score,
        "duration_seconds": duration,
        "configs_per_second": len(results) / duration,
    }
    
    print(f"  Total configurations: {metrics['total_configs']}")
    print(f"  Converged: {metrics['converged']}")
    print(f"  Best score: {metrics['best_score']:.4f}")
    print(f"  Average score: {metrics['average_score']:.4f}")
    print(f"  Duration: {duration:.1f}s")
    print(f"  Throughput: {metrics['configs_per_second']:.2f} configs/sec")
    print("=" * 60)
    print()
    
    # Save results
    save_results_to_gcs(results, metrics)
    
    print("\n✅ Training complete!\n")
    
    # Shutdown Ray
    ray.shutdown()


if __name__ == "__main__":
    main()
