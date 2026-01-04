"""List command - list all jobs"""

import subprocess


def run(args):
    """List all jobs"""
    # Check for workload context
    contexts = subprocess.run(["kubectl", "config", "get-contexts", "-o", "name"], capture_output=True, text=True).stdout.splitlines()
    kubectl_cmd = ["kubectl"]
    if "workload" in contexts:
        kubectl_cmd.extend(["--context", "workload"])
        
    print("📦 Jobs:\n")
    subprocess.run(kubectl_cmd + ["get", "jobs", "-n", "jobs"])
