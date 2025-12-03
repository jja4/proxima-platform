"""Job class - represents a training job"""

import subprocess


class Job:
    """Represents a submitted training job"""
    
    def __init__(self, name: str, namespace: str = "jobs"):
        self.name = name
        self.namespace = namespace
    
    def status(self) -> str:
        """Get job status"""
        cmd = f"kubectl get job {self.name} -n {self.namespace} -o jsonpath='{{.status.conditions[0].type}}'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip() or "Unknown"
    
    def logs(self, follow: bool = False) -> str:
        """Get job logs"""
        follow_flag = "-f" if follow else ""
        cmd = f"kubectl logs -n {self.namespace} job/{self.name} {follow_flag}"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout
    
    def wait(self, timeout: int = 3600):
        """Wait for job to complete"""
        cmd = f"kubectl wait --for=condition=complete --timeout={timeout}s job/{self.name} -n {self.namespace}"
        subprocess.run(cmd, shell=True)
    
    def delete(self):
        """Delete the job"""
        cmd = f"kubectl delete job {self.name} -n {self.namespace}"
        subprocess.run(cmd, shell=True)
