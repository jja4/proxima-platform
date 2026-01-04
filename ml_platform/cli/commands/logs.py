"""Logs command - view job logs"""

import subprocess
import sys


def run(args):
    """View job logs"""
    if len(args) < 1:
        print("Usage: ml-platform logs <job-name>")
        sys.exit(1)
    
    job_name = args[0]
    
    # Check for workload context
    contexts = subprocess.run(["kubectl", "config", "get-contexts", "-o", "name"], capture_output=True, text=True).stdout.splitlines()
    kubectl_cmd = ["kubectl"]
    if "workload" in contexts:
        kubectl_cmd.extend(["--context", "workload"])
    
    print(f"📋 Logs for {job_name}...\n")
    subprocess.run(kubectl_cmd + ["logs", "-n", "jobs", f"job/{job_name}", "-f"])
