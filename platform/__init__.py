"""
Constellaration ML Platform

A unified platform for running distributed ML training on GCP with Kubernetes and Ray.

Usage:
    # CLI
    python -m platform.cli status
    python -m platform.cli submit stellar_optimization:v1
    python -m platform.cli logs job-name
    
    # SDK
    from platform.sdk import PlatformClient
    client = PlatformClient(project_id="my-project")
    job = client.submit_job(...)
"""

__version__ = "1.0.0"
