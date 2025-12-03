"""Logs command - view job logs"""

import subprocess
import sys


def run(args):
    """View job logs"""
    if len(args) < 1:
        print("Usage: ml-platform logs <job-name>")
        sys.exit(1)
    
    job_name = args[0]
    
    print(f"📋 Logs for {job_name}...\n")
    subprocess.run(f"kubectl logs -n jobs job/{job_name} -f", shell=True)
