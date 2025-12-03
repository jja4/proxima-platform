"""
Constellaration ML Platform

A unified platform for running distributed ML training on GCP with Kubernetes and Ray.

Usage:
    # CLI
    ml-platform status
    ml-platform submit stellar_optimization:v1
    ml-platform logs job-name
    
    # SDK
    from ml_platform.sdk import PlatformClient
    client = PlatformClient(project_id="my-project")
    job = client.submit_job(...)
"""

__version__ = "1.0.0"
