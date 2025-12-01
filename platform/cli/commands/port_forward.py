"""Port-forward command - access dashboards"""

import subprocess
import sys


def run(args):
    """Port-forward to dashboards"""
    service = args[0] if len(args) > 0 else "all"
    
    if service == "ray":
        print("🚀 Ray dashboard: http://localhost:8265")
        subprocess.run(
            "kubectl port-forward -n ray-system svc/ray-cluster-head-svc 8265:8265",
            shell=True
        )
    elif service == "grafana":
        print("📊 Grafana: http://localhost:3000 (admin/admin)")
        subprocess.run(
            "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80",
            shell=True
        )
    elif service == "prometheus":
        print("📈 Prometheus: http://localhost:9090")
        subprocess.run(
            "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090",
            shell=True
        )
    elif service == "all":
        print("🌐 Port-forwarding all dashboards...\n")
        print("  Ray:        http://localhost:8265")
        print("  Grafana:    http://localhost:3000 (admin/admin)")
        print("  Prometheus: http://localhost:9090\n")
        print("Press Ctrl+C to stop\n")
        subprocess.run("""
            kubectl port-forward -n ray-system svc/ray-cluster-head-svc 8265:8265 &
            kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
            kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
            wait
        """, shell=True)
    else:
        print(f"❌ Unknown service: {service}")
        print("Available: ray, grafana, prometheus, all")
        sys.exit(1)
