#!/bin/bash

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Boilerplate >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Be safe.
set -eo pipefail
# -e: This option causes the bash script to exit immediately if any command exits with a non-zero status code, unless the command is part of a conditional expression or is followed by a || operator.
# -u: This option treats unset variables as an error and causes the script to exit if an unset variable is encountered.
# -o pipefail: This option sets the exit status of a pipeline to the rightmost non-zero exit status of any command in the pipeline. It means that if any command in a pipeline fails, the entire pipeline is considered to have failed.

# Logging
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
	printf '%s\n' "${RED}${BOLD}ERROR:${RESET} $*" >&2
}
warning() {
	printf '%s\n' "${RED}${YELLOW}WARNING:${RESET} $*"
}
info() {
	printf '%s\n' "${RED}${GREEN}INFO:${RESET} $*"
}
debug() {
	printf '%s\n' "${GREY}${GRAY}DEBUG:${RESET} $*"
}

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Boilerplate <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Arguments >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
build=false
download=false
build_with_proxy=false
run_with_proxy=false
run_with_nvidia=false

usage() {
	printf "%s\n" \
		"Usage: " \
		"${INDENT}$0 [option]" \
		""
	printf "%s\n" \
		"Options: " \
		"${INDENT}-h, --help             " \
		"${INDENT}-b, --build            " \
		"${INDENT}-d, --download         " \
		"${INDENT}-bp, --build_with_proxy" \
		"${INDENT}-rp, --run_with_proxy  " \
		"${INDENT}-rn, --run_with_nvidia " \
		""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	-b | --build)
		build=true
		shift
		;;
	-bp | --build_with_proxy)
		build_with_proxy=true
		shift
		;;
	-rp | --run_with_proxy)
		run_with_proxy=true
		shift
		;;
	-rn | --run_with_nvidia)
		run_with_nvidia=true
		shift
		;;
	-d | --download)
		download=true
		shift
		;;
	*)
		error "Unknown argument: $1"
		usage
		;;
	esac
done

if [[ $# == 0 ]]; then
	usage
fi

printf "%s\n" "${GREEN}Given Arguments${RESET}:" \
	"${INDENT}build=${BOLD}$build${RESET}" \
	"${INDENT}build_with_proxy=${BOLD}$build_with_proxy${RESET}" \
	"${INDENT}run_with_proxy=${BOLD}$run_with_proxy${RESET}" \
	"${INDENT}run_with_nvidia=${BOLD}$run_with_nvidia${RESET}" \
	"${INDENT}download=${BOLD}$download${RESET}" \
	""

# TODO: autocompletion of arguments
#
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arguments <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# The parent folder of this script.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# The default path of 'env_file' for Docker Compose
env_file=${script_dir}/.env
# Clear the file
cat /dev/null >${env_file}

buildtime_env=$(
	cat <<-END

		# >>> as services.robotics.build.args
		DOCKER_BUILDKIT=1
		OS=linux
		ARCH=amd64
		BASE_IMAGE=ubuntu:20.04
		UBUNTU_DISTRO=focal
		COMPILE_JOBS=$(nproc --all)
		XDG_PREFIX_DIR=/usr/local
		ROS_DISTRO=noetic
		# ROS2_DISTRO=humble
		# ROS2_RELEASE_DATE=20240129
		# RTI_CONNEXT_DDS_VERSION=6.0.1
		# OPENCV_VERSION=4.8.0
		# OPENCV_CONTRIB_VERSION=4.8.1
		# CERES_VERSION=2.2.0
		NEOVIM_VERSION=0.10.1
		TMUX_GIT_HASH=9ae69c3
		SETUP_TIMESTAMP=$(date +%N)
		# <<< as services.robotics.build.args

	END
)
if [[ "$build_with_proxy" == "true" ]]; then
	warning "Make sure you have configured the 'buildtime_networking_env' in setup.bash."
	buildtime_networking_env=$(
		cat <<-END

			# >>> as services.robotics.build.args
			BUILDTIME_NETWORK_MODE=host
			buildtime_http_proxy=http://127.0.0.1:1080
			buildtime_https_proxy=http://127.0.0.1:1080
			# <<< as services.robotics.build.args

		END
	)
else
	buildtime_networking_env=$(
		cat <<-END

			# >>> as services.robotics.build.args
			BUILDTIME_NETWORK_MODE=host
			# <<< as services.robotics.build.args

		END
	)
fi
if [[ "$run_with_proxy" == "true" ]]; then
	warning "Make sure you have configured the 'runtime_networking_env' in setup.bash."
	runtime_networking_env=$(
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
	runtime_networking_env=$(
		cat <<-END

			RUNTIME_NETWORK_MODE=bridge

		END
	)
fi
user_env=$(
	cat <<-END

		# >>> as services.robotics.build.args
		DOCKER_USER=robotics
		DOCKER_HOME=/home/robotics
		DOCKER_UID=$(id -u)
		DOCKER_GID=$(id -g)
		# <<< as services.robotics.build.args

	END
)
if [[ "$run_with_nvidia" == "true" ]]; then
	runtime_env=$(
		cat <<-END

			RUNTIME=nvidia
			NVIDIA_VISIBLE_DEVICES=all
			NVIDIA_DRIVER_CAPABILITIES=all
			DISPLAY=${DISPLAY}
			SDL_VIDEODRIVER=x11

		END
	)
else
	runtime_env=$(
		cat <<-END

			RUNTIME=runc
			DISPLAY=${DISPLAY}
			SDL_VIDEODRIVER=x11

		END
	)
fi

echo "# ! The file is managed by 'setup.bash'." >>${env_file}
echo "# ! Don't modify it manually. Change 'setup.bash' instead." >>${env_file}
if [[ "${build}" = true ]]; then
	echo "${buildtime_env}" >>${env_file}
	echo "${buildtime_networking_env}" >>${env_file}
	python3 "$script_dir/setup.d/build_args.py" "robotics"
fi
echo "${runtime_networking_env}" >>${env_file}
echo "${user_env}" >>${env_file}
echo "${runtime_env}" >>${env_file}
python3 "$script_dir/setup.d/nvidia.py" "robotics"
info "Environment variables are saved to ${env_file}"

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
		warning "$1 is unset. Failed to append to the downloading list."
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
	if [ ! -f "${downloads_dir}/${filename}" ]; then
		wget_paths+=("${downloads_dir}/${filename}")
		wget_urls+=("$url")
	fi
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
		debug "${#wget_urls[@]} files to download:"
		(
			IFS=$'\n'
			echo "${wget_urls[*]}"
		)
		_wget_all
	fi
}

if [ "${download}" = true ]; then
	downloads_dir="${script_dir}/downloads"
	mkdir -p "${downloads_dir}"

	_append_to_list CERES_VERSION "http://ceres-solver.org/ceres-solver-${CERES_VERSION}.tar.gz" ""
	_append_to_list OPENCV_VERSION "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz" "opencv-${OPENCV_VERSION}.tar.gz"
	_append_to_list OPENCV_CONTRIB_VERSION "https://github.com/opencv/opencv_contrib/archive/refs/tags/${OPENCV_CONTRIB_VERSION}.tar.gz" "opencv_contrib-${OPENCV_CONTRIB_VERSION}.tar.gz"
	_append_to_list ROS2_DISTRO "https://github.com/ros2/ros2/releases/download/release-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-${OS}-${UBUNTU_DISTRO}-${ARCH}.tar.bz2" ""
	_append_to_list CARLA_VERSION "https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz" ""

	_download_everything
fi

info "Done."
