import sys
import os
import re
import yaml

dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(dir, os.path.pardir))

if len(sys.argv) != 2:
    print("Please provide the service name as a command-line argument.")
    exit(1)

service_name = sys.argv[1]

# Read the contents of the bash script
with open("setup.bash", "r") as file:
    bash_content = file.read()

# Extract all build argument names from the bash script based on the specified rule
build_args_pattern = re.compile(
    r"# >>> as services\.{service}\.build\.args\s*(.*?)\s*# <<< as services\.{service}\.build\.args".format(
        service=re.escape(service_name)
    ),
    re.DOTALL,
)
build_args_matches = build_args_pattern.findall(bash_content)

build_args = {}
for match in build_args_matches:
    build_args_content = match.strip()
    for line in build_args_content.split("\n"):
        line = line.strip()
        if line and not line.startswith("#"):
            key, value = line.split("=", 1)
            build_args[key] = f"${{{key}}}"

if not build_args:
    print(
        "No build arguments found in the bash script for service '{}'.".format(
            service_name
        )
    )
    print("Please make sure the bash script contains the following lines:")
    print("# >>> as services.{}.build.args".format(service_name))
    print("# ENV_VAR_1=value1")
    print("# ENV_VAR_2=value2")
    print("# ...")
    print("# <<< as services.{}.build.args".format(service_name))
    print("Skipping the update of docker-compose.yml.")
    exit(0)

# Load the docker-compose.yml file
with open("docker-compose.yml", "r") as file:
    docker_compose = yaml.safe_load(file)

# Update the build section in the docker-compose.yml file
build = docker_compose["services"][service_name]["build"]
build["args"] = build_args

# Save the updated docker-compose.yml file
with open("docker-compose.yml", "w") as file:
    yaml.dump(docker_compose, file, default_flow_style=False)
