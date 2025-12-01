"""
Platform CLI main entry point

This module dispatches commands to their respective handlers.
"""

import sys
from .commands import status, submit, logs, scale, build, port_forward, list_jobs


COMMANDS = {
    'status': status.run,
    'submit': submit.run,
    'logs': logs.run,
    'scale': scale.run,
    'list': list_jobs.run,
    'build': build.run,
    'port-forward': port_forward.run,
}


def print_usage():
    """Print usage information"""
    print("""
Constellaration ML Platform CLI

Usage:
    platform <command> [options]

Commands:
    status                           Show platform status
    build <workload> <version>       Build and push container
    submit <workload>:<version>      Submit training job
    logs <job-name>                  View job logs
    list                             List all jobs
    scale <replicas>                 Scale Ray workers
    port-forward [ray|grafana|all]   Access dashboards

Examples:
    platform status
    platform build stellar_optimization v1.0.0
    platform submit stellar_optimization:v1.0.0
    platform logs stellar-optimization-20251201-120000
    platform scale 10
    platform port-forward ray
    """)


def main():
    """Main CLI entry point"""
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command in ['-h', '--help', 'help']:
        print_usage()
        sys.exit(0)
    
    if command not in COMMANDS:
        print(f"❌ Unknown command: {command}\n")
        print_usage()
        sys.exit(1)
    
    # Run the command
    try:
        COMMANDS[command](sys.argv[2:])
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
