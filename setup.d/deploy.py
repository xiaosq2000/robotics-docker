import os
import yaml
import argparse

dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(dir, os.path.pardir))

parser = argparse.ArgumentParser()
parser.add_argument("--compose-file", default="docker-compose.yml", type=str)
parser.add_argument("--service-name", required=True, type=str)
parser.add_argument("--run-with-nvidia", action="store_true")
args = parser.parse_args()
compose_file = args.compose_file
service_name = args.service_name
run_with_nvidia = args.run_with_nvidia

# Read the docker-compose.yml file
with open(compose_file, "r") as file:
    compose_data = yaml.safe_load(file)

# Reference:
# [1] https://docs.docker.com/compose/gpu-support/
# [2] https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/docker-specialized.html
print("For customization of docker compose deployment, you may edit", __file__)
if run_with_nvidia:
    print(f"Using all NVIDIA GPU Devices with GPU capabilities for service '{service_name}' in '{compose_file}'.")
    compose_data["services"][service_name]["deploy"] = {
        "resources": {
            "reservations": {
                "devices": [
                    {"capabilities": ["gpu"], "count": "all", "driver": "nvidia"}
                ]
            }
        }
    }
else:
    if "deploy" in compose_data["services"][service_name]:
        print(f"Removing the 'deploy' section for service '{service_name}' in '{compose_file}'.")
        del compose_data["services"][service_name]["deploy"]

with open(compose_file, "w") as file:
    yaml.dump(compose_data, file)
