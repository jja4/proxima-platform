"""Platform client - main SDK interface"""

import subprocess
import json
from datetime import datetime
from typing import Optional, Dict, List
from .job import Job


# Default TTL for completed jobs (24 hours)
DEFAULT_TTL_SECONDS = 86400


class PlatformClient:
    """Client for interacting with the ML platform"""
    
    def __init__(self, project_id: str, region: str = "europe-west3"):
        self.project_id = project_id
        self.region = region
        self.registry = f"{region}-docker.pkg.dev/{project_id}/ml-platform"
    
    def submit_job(
        self,
        name: str,
        image: str,
        command: Optional[List[str]] = None,
        env: Optional[Dict[str, str]] = None,
        cpu: str = "4",
        memory: str = "16Gi",
        cpu_limit: str = "8",
        memory_limit: str = "32Gi",
        namespace: str = "jobs",
        ttl_seconds: int = DEFAULT_TTL_SECONDS,
        backoff_limit: int = 3
    ) -> Job:
        """Submit a training job
        
        Args:
            name: Job name prefix
            image: Container image to run
            command: Optional command to run
            env: Environment variables
            cpu: CPU request
            memory: Memory request
            cpu_limit: CPU limit
            memory_limit: Memory limit
            namespace: Kubernetes namespace
            ttl_seconds: Time to live after job completion (for auto-cleanup)
            backoff_limit: Number of retries before marking job as failed
            
        Returns:
            Job object for monitoring
        """
        
        job_name = f"{name}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        
        # Build job manifest
        manifest = {
            "apiVersion": "batch/v1",
            "kind": "Job",
            "metadata": {
                "name": job_name,
                "namespace": namespace,
                "labels": {"app": name}
            },
            "spec": {
                "ttlSecondsAfterFinished": ttl_seconds,
                "backoffLimit": backoff_limit,
                "template": {
                    "spec": {
                        "restartPolicy": "Never",
                        "serviceAccountName": "job-runner",
                        "containers": [{
                            "name": "worker",
                            "image": image,
                            "env": [
                                {"name": "RAY_ADDRESS", "value": "ray://ray-cluster-head-svc.ray-system.svc.cluster.local:10001"},
                                {"name": "GCS_BUCKET", "value": f"gs://{self.project_id}-ml-artifacts"}
                            ] + [{"name": k, "value": v} for k, v in (env or {}).items()],
                            "resources": {
                                "requests": {"cpu": cpu, "memory": memory},
                                "limits": {"cpu": cpu_limit, "memory": memory_limit}
                            }
                        }]
                    }
                }
            }
        }
        
        if command:
            manifest["spec"]["template"]["spec"]["containers"][0]["command"] = command
        
        # Apply manifest (use JSON instead of YAML)
        json_str = json.dumps(manifest)
        result = subprocess.run(
            ["kubectl", "apply", "-f", "-"],
            input=json_str,
            text=True,
            capture_output=True
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"Failed to submit job: {result.stderr}")
        
        return Job(job_name, namespace)
    
    def list_jobs(self, namespace: str = "jobs") -> List[Dict]:
        """List all jobs"""
        cmd = f"kubectl get jobs -n {namespace} -o json"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            return data.get("items", [])
        return []
    
    def delete_job(self, name: str, namespace: str = "jobs") -> bool:
        """Delete a job by name"""
        cmd = f"kubectl delete job {name} -n {namespace}"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"Failed to delete job: {result.stderr}")
        return True
    
    def cleanup_completed_jobs(self, namespace: str = "jobs") -> int:
        """Delete all completed jobs. Returns count of deleted jobs."""
        jobs = self.list_jobs(namespace)
        deleted = 0
        for job in jobs:
            status = job.get("status", {})
            if status.get("succeeded", 0) > 0 or status.get("failed", 0) > 0:
                name = job["metadata"]["name"]
                try:
                    self.delete_job(name, namespace)
                    deleted += 1
                except RuntimeError:
                    pass
        return deleted
    
    def scale_ray(self, replicas: int):
        """Scale Ray workers"""
        cmd = f"kubectl scale raycluster ray-cluster --replicas={replicas} -n ray-system"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"Failed to scale: {result.stderr}")
        return True
    
    def get_status(self) -> Dict:
        """Get platform status"""
        def run(cmd):
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.stdout.strip()
        
        return {
            "nodes": run("kubectl get nodes --no-headers | wc -l").strip(),
            "ray_pods": run("kubectl get pods -n ray-system --no-headers | grep Running | wc -l").strip(),
            "total_jobs": run("kubectl get jobs -n jobs --no-headers | wc -l").strip(),
            "running_jobs": run("kubectl get pods -n jobs --field-selector=status.phase=Running --no-headers | wc -l").strip(),
        }
