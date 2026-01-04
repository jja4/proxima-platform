"""Port-forward command - access dashboards"""

import subprocess
import sys


def run_port_forward(ctx, namespace, resource, local_port, remote_port):
    """Helper to run port-forward with existence check"""
    # Check if resource exists
    check_cmd = f"kubectl {ctx} get {resource} -n {namespace} --no-headers 2>/dev/null"
    result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"⚠️  {resource} not found in namespace {namespace} ({ctx if ctx else 'current context'})")
        return None
    
    cmd = f"kubectl {ctx} port-forward -n {namespace} {resource} {local_port}:{remote_port}"
    return subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def run(args):
    """Port-forward to dashboards"""
    service = args[0] if len(args) > 0 else "all"
    
    # Check for contexts
    contexts = subprocess.run(["kubectl", "config", "get-contexts", "-o", "name"], capture_output=True, text=True).stdout.splitlines()
    
    workload_ctx = ""
    if "workload" in contexts:
        workload_ctx = "--context workload"
        
    mgmt_ctx = ""
    if "management" in contexts:
        mgmt_ctx = "--context management"

    processes = []

    if service in ["ray", "all"]:
        print("🚀 Ray dashboard: http://localhost:8265")
        p = run_port_forward(workload_ctx, "ray-system", "svc/ray-cluster-head-svc", 8265, 8265)
        if p: processes.append(p)
        elif service == "ray": sys.exit(1)

    if service in ["grafana", "all"]:
        print("📊 Grafana: http://localhost:3000 (admin/admin)")
        # Try both common names
        p = run_port_forward(mgmt_ctx, "monitoring", "svc/grafana", 3000, 80)
        if not p:
            p = run_port_forward(mgmt_ctx, "monitoring", "svc/prometheus-grafana", 3000, 80)
        
        if p: processes.append(p)
        elif service == "grafana": sys.exit(1)

    if service in ["prometheus", "all"]:
        print("📈 Prometheus: http://localhost:9090")
        p = run_port_forward(mgmt_ctx, "monitoring", "svc/prometheus-server", 9090, 80)
        if not p:
            p = run_port_forward(mgmt_ctx, "monitoring", "svc/prometheus-kube-prometheus-prometheus", 9090, 9090)
        
        if p: processes.append(p)
        elif service == "prometheus": sys.exit(1)

    if not processes:
        if service == "all":
            print("\n❌ No services found to port-forward. Is the platform deployed?")
        sys.exit(1)

    print("\nPress Ctrl+C to stop\n")
    try:
        # Wait for all processes
        for p in processes:
            p.wait()
    except KeyboardInterrupt:
        print("\n👋 Stopping port-forwards...")
        for p in processes:
            p.terminate()
