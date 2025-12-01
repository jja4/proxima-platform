# Kubernetes Monitoring Configuration

This directory contains Grafana dashboards and Prometheus alerting rules for monitoring the ML training platform.

## Dashboards

- **ray-dashboard.json**: Ray cluster metrics (workers, CPU, memory, tasks)
- **jobs-dashboard.json**: ML training job metrics (success rate, duration, failures)

## Alerts

- **ray-alerts.yaml**: Ray cluster health alerts
- **job-alerts.yaml**: ML job failure and performance alerts

## Applying Configuration

```bash
# Apply dashboards
kubectl apply -f dashboards.yaml

# Apply alerts
kubectl apply -f alerts.yaml
```

## Accessing Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
open http://localhost:3000
```

Default credentials: `admin` / `admin`

## Customizing Alerts

Edit alert thresholds in `alerts.yaml`:

```yaml
# Example: Change memory threshold from 90% to 80%
expr: (ray_node_mem_used / ray_node_mem_total) > 0.8
```

## Adding New Dashboards

1. Create dashboard in Grafana UI
2. Export JSON
3. Add to `dashboards.yaml` ConfigMap
4. Apply: `kubectl apply -f dashboards.yaml`
