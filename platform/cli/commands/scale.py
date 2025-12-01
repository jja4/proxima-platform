"""Scale command - scale Ray workers"""

import subprocess
import sys


def run_cmd(cmd: str) -> tuple:
    """Run shell command and return output"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip(), result.returncode


def run(args):
    """Scale Ray workers"""
    if len(args) < 1:
        print("Usage: platform scale <replicas>")
        print("Example: platform scale 10")
        sys.exit(1)
    
    replicas = args[0]
    
    print(f"⚖️  Scaling Ray to {replicas} workers...\n")
    out, code = run_cmd(f"kubectl scale raycluster ray-cluster --replicas={replicas} -n ray-system")
    
    if code == 0:
        print(f"✅ Scaled to {replicas} workers")
    else:
        print(f"❌ Error: {out}")
        sys.exit(1)
