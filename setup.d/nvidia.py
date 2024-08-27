import sys
import os
import yaml

dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(dir, os.path.pardir))

if len(sys.argv) != 2:
    print("Please provide the service name as a command-line argument.")
    exit(1)

service_name = sys.argv[1]

env_file = ".env"
compose_file = "docker-compose.yml"

# Read the configuration file
with open(env_file, "r") as file:
    run_with_nvidia = False
    for line in file:
        if "RUNTIME=nvidia" in line:
            run_with_nvidia = True
            break

# Read the docker-compose.yml file
with open(compose_file, "r") as file:
    compose_data = yaml.safe_load(file)

if run_with_nvidia:
    compose_data["services"][service_name]["deploy"] = {
        "resources": {
            "reservations": {
                "devices": [
                    {"capabilities": ["gpu"], "device_ids": ["0"], "driver": "nvidia"}
                ]
            }
        }
    }
else:
    if "deploy" in compose_data["services"][service_name]:
        del compose_data["services"][service_name]["deploy"]

with open(compose_file, "w") as file:
    yaml.dump(compose_data, file)
