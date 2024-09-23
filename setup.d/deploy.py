import os
import yaml
import argparse
from typing import Dict, Any


def nested_set(dic: Dict[str, Any], keys: list, value: Any) -> None:
    for key in keys[:-1]:
        dic = dic.setdefault(key, {})
    dic[keys[-1]] = value


dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(dir, os.path.pardir))

parser = argparse.ArgumentParser(
    description="Modify a Docker Compose file to adjust service configurations, "
    "including GPU support, CPU, and memory resource allocation.",
    formatter_class=argparse.RawDescriptionHelpFormatter,
    epilog="""
Examples:
  python deploy.py --service-name myservice --nvidia --cpu-limit 0.5 --cpu-reservation 0.1 --memory-limit 1G --memory-reservation 512M
  python deploy.py --service-name webserver --compose-file custom-compose.yml --verbose
  python deploy.py --service-name database --cpu-limit 2 --memory-limit 2G --verbose

Note:
  This script modifies the specified Docker Compose file in-place. 
  Make sure to backup your original file if needed.
  Memory values should be specified with a unit (e.g., B, K, M, G).
""",
)

parser.add_argument(
    "--compose-file",
    default="docker-compose.yml",
    type=str,
    help="Path to the Docker Compose file (default: docker-compose.yml in the parent directory)",
)

parser.add_argument(
    "--service-name",
    required=True,
    type=str,
    help="Name of the service in the Docker Compose file to modify",
)

parser.add_argument("--clear", action="store_true", help="Delete the 'deploy' section")

parser.add_argument(
    "--nvidia",
    action="store_true",
    help="Enable NVIDIA GPU support for the specified service",
)

parser.add_argument(
    "--verbose",
    action="store_true",
    help="Enable verbose output for detailed operation information",
)

parser.add_argument(
    "--cpu-limit",
    type=float,
    help="Set CPU usage limit for the service (e.g., 0.5 for half a CPU, 2 for two CPUs)",
)

parser.add_argument(
    "--cpu-reservation",
    type=float,
    help="Set CPU reservation for the service (e.g., 0.1 for 10%% of a CPU, 1 for one full CPU)",
)

parser.add_argument(
    "--memory-limit",
    type=str,
    help="Set memory usage limit for the service (e.g., 512M, 1G)",
)

parser.add_argument(
    "--memory-reservation",
    type=str,
    help="Set memory reservation for the service (e.g., 256M, 1G)",
)

args = parser.parse_args()

# Read the docker-compose.yml file
with open(args.compose_file, "r") as file:
    compose_data = yaml.safe_load(file)

if args.verbose:
    print(
        f"For customization of docker compose deployment, you may edit {args.compose_file}"
    )

if args.clear:
    if "deploy" in compose_data["services"][args.service_name]:
        del compose_data["services"][args.service_name]["deploy"]
        exit(0)

# Add NVIDIA GPU configuration if requested
if args.nvidia:
    if args.verbose:
        print(
            f"Using all NVIDIA GPU Devices with GPU capabilities for service '{args.service_name}' in '{args.compose_file}'."
        )

    nested_set(
        compose_data["services"][args.service_name],
        ["deploy", "resources", "reservations", "devices"],
        [{"capabilities": ["gpu"], "count": "all", "driver": "nvidia"}],
    )

# Add CPU resource allocation if specified
if args.cpu_limit is not None:
    nested_set(
        compose_data["services"][args.service_name],
        ["deploy", "resources", "limits", "cpus"],
        args.cpu_limit,
    )
    if args.verbose:
        print(
            f"Setting CPU limit to {args.cpu_limit} for service '{args.service_name}'"
        )

if args.cpu_reservation is not None:
    nested_set(
        compose_data["services"][args.service_name],
        ["deploy", "resources", "reservations", "cpus"],
        args.cpu_reservation,
    )
    if args.verbose:
        print(
            f"Setting CPU reservation to {args.cpu_reservation} for service '{args.service_name}'"
        )

# Add memory resource allocation if specified
if args.memory_limit is not None:
    nested_set(
        compose_data["services"][args.service_name],
        ["deploy", "resources", "limits", "memory"],
        args.memory_limit,
    )
    if args.verbose:
        print(
            f"Setting memory limit to {args.memory_limit} for service '{args.service_name}'"
        )

if args.memory_reservation is not None:
    nested_set(
        compose_data["services"][args.service_name],
        ["deploy", "resources", "reservations", "memory"],
        args.memory_reservation,
    )
    if args.verbose:
        print(
            f"Setting memory reservation to {args.memory_reservation} for service '{args.service_name}'"
        )

# Write the updated docker-compose.yml file
with open(args.compose_file, "w") as file:
    yaml.dump(compose_data, file)

if args.verbose:
    print(f"Updated {args.compose_file} successfully.")
