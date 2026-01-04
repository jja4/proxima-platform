"""Scale command - scale Ray workers"""

import subprocess
import sys
import json


def run_cmd(cmd: str) -> tuple:
    """Run shell command and return output"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip(), result.returncode, result.stderr.strip()


def run(args):
    """Scale Ray workers"""
    if len(args) < 1:
        print("Usage: ml-platform scale <replicas>")
        print("Example: ml-platform scale 10")
        sys.exit(1)
    
    replicas = args[0]
    
    # Check for workload context
    contexts = subprocess.run(["kubectl", "config", "get-contexts", "-o", "name"], capture_output=True, text=True).stdout.splitlines()
    ctx_flag = ""
    if "workload" in contexts:
        ctx_flag = "--context workload"
    
    print(f"⚖️  Scaling Ray to {replicas} workers...\n")
    
    # Use kubectl patch with JSON patch to update worker replicas
    # This updates only the replicas field while preserving other spec fields
    patch = json.dumps([{"op": "replace", "path": "/spec/workerGroupSpecs/0/replicas", "value": int(replicas)}])
    cmd = f"kubectl {ctx_flag} patch raycluster ray-cluster-kuberay -n ray-system --type json -p '{patch}'"
    out, code, err = run_cmd(cmd)
    
    if code == 0:
        print(f"✅ Scaled to {replicas} workers")
        print(f"   Updating Ray worker pods (may take ~30 seconds)...")
        
        # Wait for pods to update
        check_cmd = f"kubectl {ctx_flag} get pods -n ray-system -l ray.io/node-type=worker --no-headers | wc -l"
        check_out, _, _ = run_cmd(check_cmd)
        current_workers = int(check_out)
        print(f"   Current workers: {current_workers}")
    else:
        print(f"❌ Error: {err if err else out}")
        sys.exit(1)


