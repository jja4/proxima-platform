"""List command - list all jobs"""

import subprocess


def run(args):
    """List all jobs"""
    print("📦 Jobs:\n")
    subprocess.run("kubectl get jobs -n jobs", shell=True)
