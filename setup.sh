#!/usr/bin/env bash
set -euo pipefail
INDENT='    '
BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"
error() {
	printf '%s\n' "${BOLD}${RED}ERROR:${RESET} $*" >&2
}
warning() {
	printf '%s\n' "${BOLD}${YELLOW}WARNING:${RESET} $*"
}
info() {
	printf '%s\n' "${BOLD}${GREEN}INFO:${RESET} $*"
}
debug() {
	set +u
	if [[ "$VERBOSE" == "true" ]]; then
		set -u
		printf '%s\n' "${BOLD}${GREY}DEBUG:${RESET} $*"
	fi
}
completed() {
	printf '%s\n' "${BOLD}${GREEN}✓${RESET} $*"
}

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Arguments >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
BUILD=false
ENSURE_DOWNLOAD=false
BUILD_PROXY=false
RUN_PROXY=false
NVIDIA=false
WAYLAND=false

display_help_messages() {
	printf "%s\n" \
		"Usage: " \
		"${INDENT}$0 [option]" \
		"" \
		"${INDENT}Download specified build-time dependencies." \
		"${INDENT}Generate 'docker-compose.yml' and '.env' for Docker build-time and run-time usage." \
		"" \
		"${INDENT}${BOLD}Before running, You could check out the environment variables written in '$0'.${RESET}" \
		"" \
		"${INDENT}Recommended command for the first time," \
		"" \
		"${INDENT}${INDENT}\$ $0 -b -d -n" \
		""
	printf "%s\n" \
		"Options: " \
		"" \
		"${INDENT}-b, --build            Generate build-time environment variables for 'docker-compose.yml'." \
		"${INDENT}                       If not given, only run-time environment variables will be generated." \
		"${INDENT}-d, --download         Ensure some build-time dependencies are downloaded to './downloads'." \
		"" \
		"${INDENT}-bp, --build-proxy     Use networking proxy for docker image build-time." \
		"${INDENT}-rp, --run-proxy       Use networking proxy for docker container run-time." \
		"" \
		"${INDENT}-n, --nvidia           Configure NVIDIA container runtime. Make sure the nvidia container toolkit is installed and configured." \
		"${INDENT}                       Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html" \
		"" \
		"${INDENT}-w, --wayland          Configure (X)WAYLAND run-time environment variables." \
		"${INDENT}                       If not given, X11 run-time environment variables will be configured." \
		"" \
		"${INDENT}-h, --help             Display help messages." \
		"${INDENT}--verbose              Display verbose logging for debugging." \
		""
}

# TODO: autocompletion of arguments
# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		display_help_messages
		exit 0
		;;
	--verbose)
		VERBOSE=true
		shift
		;;
	-b | --build)
		BUILD=true
		shift
		;;
	-d | --download)
		ENSURE_DOWNLOAD=true
		shift
		;;
	-bp | --build-proxy)
		BUILD_PROXY=true
		shift
		;;
	-rp | --run-proxy)
		RUN_PROXY=true
		shift
		;;
	-n | --nvidia)
		NVIDIA=true
		shift
		;;
	-w | --wayland)
		WAYLAND=true
		shift
		;;
	*)
		error "Unknown argument: $1"
		display_help_messages
		exit 1
		;;
	esac
done

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arguments <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# The parent folder of this script.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# The default path of 'env_file' for Docker Compose
env_file=${script_dir}/.env
# Clear the file
cat /dev/null >${env_file}

SERVICE_NAME="robotics"
python3 "$script_dir/setup.d/deploy.py" --service-name "${SERVICE_NAME}" --clear
compose_env=$(
	cat <<-END

		IMAGE_NAME=robotics
		IMAGE_TAG=noble
		CONTAINER_NAME=robotics-noble
		BUILD_TARGET=gsplat

	END
)
build_env=$(
	cat <<-END

		# >>> as services.${SERVICE_NAME}.build.args
		DOCKER_BUILDKIT=1
		OS=linux
		ARCH=amd64
		BASE_IMAGE=nvidia/cuda:12.5.1-devel-ubuntu24.04
		COMPILE_JOBS=$(($(nproc --all) / 4))
		XDG_PREFIX_DIR=/usr/local
		# ROS1_DISTRO=noetic
		ROS2_DISTRO=jazzy
		# ROS2_RELEASE_DATE=20240129
		# RTI_CONNEXT_DDS_VERSION=6.0.1
		OPENCV_VERSION=4.10.0
		OPENCV_CONTRIB_VERSION=4.10.0
		CMAKE_VERSION=3.30.3
		CERES_VERSION=2.2.0
		BOOST_VERSION=1.86.0
		FLANN_VERSION=1.9.2
		VTK_VERSION=9.3.1
		PCL_GIT_REFERENCE=d1c34a8
		NEOVIM_VERSION=0.10.1
		TMUX_GIT_REFERENCE=3.4
		# SETUP_TIMESTAMP=$(date +%N)
		SETUP_TIMESTAMP=0
		# <<< as services.${SERVICE_NAME}.build.args

	END
)
if [[ "$BUILD_PROXY" == "true" ]]; then
	build_networking_env=$(
		cat <<-END

			# >>> as services.${SERVICE_NAME}.build.args
			BUILDTIME_NETWORK_MODE=host
			buildtime_http_proxy=http://127.0.0.1:1080
			buildtime_https_proxy=http://127.0.0.1:1080
			# <<< as services.${SERVICE_NAME}.build.args

		END
	)
else
	build_networking_env=$(
		cat <<-END

			# >>> as services.${SERVICE_NAME}.build.args
			BUILDTIME_NETWORK_MODE=host
			# <<< as services.${SERVICE_NAME}.build.args

		END
	)
fi
debug "$build_networking_env"

if [[ "$RUN_PROXY" == "true" ]]; then
	run_networking_env=$(
		cat <<-END

			RUNTIME_NETWORK_MODE=bridge
			http_proxy=http://host.docker.internal:1080
			https_proxy=http://host.docker.internal:1080
			HTTP_PROXY=http://host.docker.internal:1080
			HTTPS_PROXY=http://host.docker.internal:1080
			# RUNTIME_NETWORK_MODE=host
			# http_proxy=http://127.0.0.1:1080
			# https_proxy=http://127.0.0.1:1080
			# HTTP_PROXY=http://127.0.0.1:1080
			# HTTPS_PROXY=http://127.0.0.1:1080

		END
	)
else
	run_networking_env=$(
		cat <<-END

			RUNTIME_NETWORK_MODE=bridge

		END
	)
fi
debug "$run_networking_env"

run_and_build_user_env=$(
	cat <<-END

		# >>> as services.${SERVICE_NAME}.build.args
		DOCKER_USER=robotics
		DOCKER_HOME=/home/robotics
		DOCKER_UID=$(id -u)
		DOCKER_GID=$(id -g)
		# <<< as services.${SERVICE_NAME}.build.args

	END
)
if [[ "$NVIDIA" == "true" ]]; then
	container_runtime_env=$(
		cat <<-END

			RUNTIME=nvidia
			NVIDIA_VISIBLE_DEVICES=all
			NVIDIA_DRIVER_CAPABILITIES=all

		END
	)
	python3 "$script_dir/setup.d/deploy.py" --service-name ${SERVICE_NAME} --nvidia
else
	container_runtime_env=$(
		cat <<-END

			RUNTIME=runc

		END
	)
fi
if [[ "${WAYLAND}" == true ]]; then
	display_runtime_env=$(
		cat <<-END

			DISPLAY=${DISPLAY}
			DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"
			WAYLAND_DISPLAY=${WAYLAND_DISPLAY}
			QT_QPA_PLATFORM=wayland
			GDK_BACKEND=wayland
			CLUTTER_BACKEND=wayland
			SDL_VIDEODRIVER=wayland
			ELM_DISPLAY=wl
			ELM_ACCEL=opengl
			ECORE_EVAS_ENGINE=wayland_egl

		END
	)
	debug "Using Wayland and Xwayland."
	python3 "$script_dir/setup.d/volumes.py" --service-name "${SERVICE_NAME}" --wayland --x11 --dbus
else
	display_runtime_env=$(
		cat <<-END

			DISPLAY=${DISPLAY}
			DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"

		END
	)
	python3 "$script_dir/setup.d/volumes.py" --service-name "${SERVICE_NAME}" --x11 --dbus
fi
resource_allocation_env=$(
	cat <<-END

		CPU_LIMIT="$(($(grep -c '^processor' /proc/cpuinfo) / 2))"
		MEMORY_LIMIT="$(($(free -m | grep '^Mem' | awk '{ print $2; }') / 2))M"

	END
)
echo "# ! The file is managed by '$(basename "$0")'." >>${env_file}
echo "# ! Don't edit it manually. Change '$(basename "$0")' instead." >>${env_file}
echo "${compose_env}" >>${env_file}
echo "${run_and_build_user_env}" >>${env_file}
if [[ "${BUILD}" = true ]]; then
	echo "${build_env}" >>${env_file}
	echo "${build_networking_env}" >>${env_file}
	python3 "$script_dir/setup.d/build_args.py" "${SERVICE_NAME}"
fi
echo "${run_networking_env}" >>${env_file}

echo "${container_runtime_env}" >>${env_file}
echo "${resource_allocation_env}" >>${env_file}

echo "${display_runtime_env}" >>${env_file}
debug "Environment variables are saved to ${env_file}"
debug "
$(cat ${env_file})
"

# Load varibles from a file
# Reference: https://stackoverflow.com/a/30969768
set -o allexport && source ${env_file} && set +o allexport

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Downloads <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# TODO: md5 check or something to prevent corruption.
# Three helper functions for downloading.
wget_urls=()
wget_paths=()
_append_to_list() {
	# $1: flag
	if [ -z "$(eval echo "\$$1")" ]; then
		warning "$1 is unset or empty. Failed to append to the downloading list."
		return 0
	fi
	# $2: url
	url="$2"
	# $3: filename
	if [ -z "$3" ]; then
		filename=$(basename "$url")
	else
		filename="$3"
	fi
	wget_paths+=("${downloads_dir}/${filename}")
	wget_urls+=("$url")
}
_wget_all() {
	for i in "${!wget_urls[@]}"; do
		wget "${wget_urls[i]}" -q -c --show-progress -O "${wget_paths[i]}"
	done
}
_download_everything() {
	# a wrapper of the function "wget_all"
	if [ ${#wget_urls[@]} = 0 ]; then
		debug "No download tasks."
	else
		debug "Check ${#wget_urls[@]} files:
$(printf '%s\n' ${wget_urls[@]})"
		_wget_all
	fi
}

if [ "${ENSURE_DOWNLOAD}" = true ]; then
	downloads_dir="${script_dir}/downloads"
	mkdir -p "${downloads_dir}"

	_append_to_list CERES_VERSION "http://ceres-solver.org/ceres-solver-${CERES_VERSION}.tar.gz" ""
	_append_to_list BOOST_VERSION "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_$(echo ${BOOST_VERSION} | sed 's/\./_/g').tar.gz" "boost-${BOOST_VERSION}.tar.gz"
	_append_to_list FLANN_VERSION "https://github.com/flann-lib/flann/archive/refs/tags/${FLANN_VERSION}.tar.gz" "flann-${FLANN_VERSION}.tar.gz"
	_append_to_list VTK_VERSION "https://www.vtk.org/files/release/$(echo ${VTK_VERSION} | cut -d '.' -f 1,2)/VTK-${VTK_VERSION}.tar.gz" "vtk-${VTK_VERSION}.tar.gz"
	_append_to_list OPENCV_VERSION "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz" "opencv-${OPENCV_VERSION}.tar.gz"
	_append_to_list OPENCV_CONTRIB_VERSION "https://github.com/opencv/opencv_contrib/archive/refs/tags/${OPENCV_CONTRIB_VERSION}.tar.gz" "opencv_contrib-${OPENCV_CONTRIB_VERSION}.tar.gz"
	# _append_to_list ROS2_DISTRO "https://github.com/ros2/ros2/releases/download/release-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-${OS}-${UBUNTU_DISTRO}-${ARCH}.tar.bz2" ""
	# _append_to_list CARLA_VERSION "https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz" ""

	_download_everything
fi

completed "Done!"
