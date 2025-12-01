"""Status command - show platform health"""

import subprocess


def run_cmd(cmd: str) -> tuple:
    """Run shell command and return output"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip(), result.returncode


def run(args):
    """Show platform status"""
    print("🔍 Platform Status\n")
    
    print("Cluster:")
    out, _ = run_cmd("kubectl get nodes --no-headers 2>/dev/null | wc -l")
    print(f"  Nodes: {out or 'Not connected'}")
    
    print("\nRay Cluster:")
    out, _ = run_cmd("kubectl get pods -n ray-system --no-headers 2>/dev/null | grep Running | wc -l")
    print(f"  Running pods: {out or '0'}")
    
    print("\nJobs:")
    out, _ = run_cmd("kubectl get jobs -n jobs --no-headers 2>/dev/null | wc -l")
    print(f"  Total: {out or '0'}")
    out, _ = run_cmd("kubectl get jobs -n jobs --no-headers 2>/dev/null | grep -c '1/1' || echo 0")
    print(f"  Completed: {out}")
    out, _ = run_cmd("kubectl get pods -n jobs --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l")
    print(f"  Running: {out or '0'}")
    
    print()
