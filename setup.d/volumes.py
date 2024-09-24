import os
import yaml
import argparse

dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(dir, os.path.pardir))

parser = argparse.ArgumentParser(
    description="Modify a Docker Compose file to adjust service configurations, "
    "including Wayland, X11, DBus socket mounting.",
    formatter_class=argparse.RawDescriptionHelpFormatter,
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

parser.add_argument("--clear", action="store_true", help="Delete the 'volumes' section")

parser.add_argument(
    "--verbose",
    action="store_true",
    help="Enable verbose output for detailed operation information",
)

parser.add_argument(
    "--wayland",
    action="store_true",
    help="Mount Wayland socket",
)

parser.add_argument(
    "--wayland-volume",
    type=str,
    default="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY:rw",
    help="Default: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY:rw",
)

parser.add_argument(
    "--x11",
    action="store_true",
    help="Mount X11 socket",
)

parser.add_argument(
    "--x11-volume",
    type=str,
    default="/tmp/.X11-unix:/tmp/.X11-unix:rw",
    help="Default: /tmp/.X11-unix:/tmp/.X11-unix:rw",
)

parser.add_argument(
    "--dbus",
    action="store_true",
    help="Mount DBus socket",
)

parser.add_argument(
    "--dbus-volume",
    type=str,
    default="/run/user/1000/bus:/run/user/1000/bus:rw",
    help="Default: /run/user/1000/bus:/run/user/1000/bus:rw",
)

args = parser.parse_args()

# Read the docker-compose.yml file
with open(args.compose_file, "r") as file:
    compose_data = yaml.safe_load(file)

if args.clear:
    if "volumes" in compose_data["services"][args.service_name]:
        del compose_data["services"][args.service_name]["volumes"]
        exit(0)

# Handle volumes
if "volumes" not in compose_data["services"][args.service_name]:
    compose_data["services"][args.service_name]["volumes"] = []

volumes = compose_data["services"][args.service_name]["volumes"]

# Handle Wayland socket mounting
wayland_volume = args.wayland_volume
if args.wayland:
    if wayland_volume not in volumes:
        volumes.append(wayland_volume)
        if args.verbose:
            print(f"Added Wayland socket mount for service '{args.service_name}'")
else:
    if wayland_volume in volumes:
        volumes.remove(wayland_volume)
        if args.verbose:
            print(f"Removed Wayland socket mount from service '{args.service_name}'")

# Handle X11 socket mounting
x11_volume = args.x11_volume
if args.x11:
    if x11_volume not in volumes:
        volumes.append(x11_volume)
        if args.verbose:
            print(f"Added X11 socket mount for service '{args.service_name}'")
    # reference: https://github.com/mviereck/x11docker/wiki/Short-setups-to-provide-X-display-to-container
    compose_data["services"][args.service_name]["ipc"] = "host"
else:
    if x11_volume in volumes:
        volumes.remove(x11_volume)
        if args.verbose:
            print(f"Removed X11 socket mount from service '{args.service_name}'")

# Handle DBus socket mounting
dbus_volume = args.dbus_volume
if args.dbus:
    if dbus_volume not in volumes:
        volumes.append(dbus_volume)
        if args.verbose:
            print(f"Added DBus socket mount for service '{args.service_name}'")
else:
    if dbus_volume in volumes:
        volumes.remove(dbus_volume)
        if args.verbose:
            print(f"Removed DBus socket mount from service '{args.service_name}'")

# Write the updated docker-compose.yml file
with open(args.compose_file, "w") as file:
    yaml.dump(compose_data, file)

if args.verbose:
    print(f"Updated {args.compose_file} successfully.")
