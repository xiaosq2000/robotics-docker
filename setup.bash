#!/bin/bash

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Arguments >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
TO_BUILD=true
TO_DOWNLOAD=true
BUILD_WITH_PROXY=false
RUN_WITH_PROXY=false
RUN_WITH_NVIDIA=true
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arguments <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Be safe.
set -euo pipefail

# Simple CLI Logging
NOCOLOR='\033[0m' # No Color
# Regular Colors
BLACK='\033[0;30m'  # Black
RED='\033[0;31m'    # Red
GREEN='\033[0;32m'  # Green
YELLOW='\033[0;33m' # Yellow
BLUE='\033[0;34m'   # Blue
PURPLE='\033[0;35m' # Purple
CYAN='\033[0;36m'   # Cyan
WHITE='\033[0;37m'  # White
# BOLD
BBLACK='\033[1;30m'  # Black
BRED='\033[1;31m'    # Red
BGREEN='\033[1;32m'  # Green
BYELLOW='\033[1;33m' # Yellow
BBLUE='\033[1;34m'   # Blue
BPURPLE='\033[1;35m' # Purple
BCYAN='\033[1;36m'   # Cyan
BWHITE='\033[1;37m'  # White

error() {
	echo -e "${BRED}ERROR:${NOCOLOR} $1"
}
info() {
	echo -e "${BGREEN}INFO:${NOCOLOR} $1"
}
warning() {
	echo -e "${BYELLOW}WARNING:${NOCOLOR} $1"
}

# The parent folder of this script.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# The default path of 'env_file' for Docker Compose
env_file=${script_dir}/.env
# Backup and clear the env_file
if [ -f ${env_file} ]; then
	mv ${env_file} ${env_file}.bak
fi
cat /dev/null >${env_file}

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
buildtime_env=$(
	cat <<-END

		# >>> as 'service.build.args' in docker-compose.yml >>>
		DOCKER_BUILDKIT=1
		OS=linux
		ARCH=amd64
		BASE_IMAGE=ubuntu:20.04
		UBUNTU_DISTRO=focal
		COMPILE_JOBS=28
		DEPENDENCIES_DIR=/usr/local
		ROS_DISTRO=noetic
		# ROS2_DISTRO=humble
		# ROS2_RELEASE_DATE=20240129
		# RTI_CONNEXT_DDS_VERSION=6.0.1
		# OPENCV_VERSION=4.8.0
		# OPENCV_CONTRIB_VERSION=4.8.1
		# CERES_VERSION=2.2.0
		NEOVIM_VERSION=0.10.1
		TMUX_GIT_HASH=9ae69c3
		# DOTFILES_GIT_HASH=9233a3e
		# SETUP_TIMESTAMP=$(date +%N)
		# <<< as 'service.build.args' in docker-compose.yml <<<

	END
)

buildtime_proxy_env=$(
	cat <<-END

		BUILDTIME_NETWORK_MODE=host
		# >>> as 'service.build.args' in docker-compose.yml >>>
		# Pay attention:
		# http_proxy: \${buildtime_http_proxy}
		# ...
		buildtime_http_proxy=http://127.0.0.1:1080
		buildtime_https_proxy=http://127.0.0.1:1080
		BUILDTIME_HTTP_PROXY=http://127.0.0.1:1080
		BUILDTIME_HTTPS_PROXY=http://127.0.0.1:1080
		# <<< as 'service.build.args' in docker-compose.yml <<<

	END
)
runtime_networking_env=$(
	cat <<-END

		# RUNTIME_NETWORK_MODE=bridge
		# http_proxy=http://host.docker.internal:1080
		# https_proxy=http://host.docker.internal:1080
		# HTTP_PROXY=http://host.docker.internal:1080
		# HTTPS_PROXY=http://host.docker.internal:1080
		RUNTIME_NETWORK_MODE=host
		# http_proxy=http://127.0.0.1:1080
		# https_proxy=http://127.0.0.1:1080
		# HTTP_PROXY=http://127.0.0.1:1080
		# HTTPS_PROXY=http://127.0.0.1:1080

	END
)
user_env=$(
	cat <<-END

		# >>> as 'service.build.args' in docker-compose.yml >>>
		DOCKER_USER=robotics
		DOCKER_UID=$(id -u)
		DOCKER_GID=$(id -g)
		# <<< as 'service.build.args' in docker-compose.yml <<<

	END
)
runtime_env=$(
	cat <<-END

		RUNTIME=runc
		DISPLAY=${DISPLAY}
		SDL_VIDEODRIVER=x11

	END
)
nvidia_runtime_env=$(
	cat <<-END

		RUNTIME=nvidia
		NVIDIA_VISIBLE_DEVICES=all
		NVIDIA_DRIVER_CAPABILITIES=all
		DISPLAY=${DISPLAY}
		SDL_VIDEODRIVER=x11

	END
)
# <<<<<<<<<<<<<<<<<<<<<<<<<< Environment Variables <<<<<<<<<<<<<<<<<<<<<<<<<<<<<

echo "# The file is managed by 'setup.bash'." >>${env_file}

if [ "${TO_BUILD}" = true ]; then
	echo "${buildtime_env}" >>${env_file}
else
	echo -e "Warning: TO_BUILD=false\n\tMake sure the Docker image is ready."
fi
if [ "${BUILD_WITH_PROXY}" = true ]; then
	echo "${buildtime_proxy_env}" >>${env_file}
else
	warning "BUILD_WITH_PROXY=false\n\tChinese GFW may corrupt networking in the building stage."
fi
warning "You may check out the runtime networking environment variables."
echo "${runtime_networking_env}" >>${env_file}
echo "${user_env}" >>${env_file}
if [ "${RUN_WITH_NVIDIA}" = true ]; then
	echo "${nvidia_runtime_env}" >>${env_file}
else
	echo "${runtime_env}" >>${env_file}
fi

info "Environment variables are saved to ${env_file}"
# # Print the env_file to stdout
# cat ${env_file}

# Load varibles from ${env_file} for further usage.
# Reference: https://stackoverflow.com/a/30969768
set -o allexport && source ${env_file} && set +o allexport

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Downloads <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# TODO: md5 check or something to prevent corruption.

downloads_dir="${script_dir}/downloads"
mkdir -p "${downloads_dir}"

# Three helper functions for downloading.
wget_urls=()
wget_paths=()
append_to_list() {
	# $1: flag
	if [ -z "$(eval echo "\$$1")" ]; then
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
wget_all() {
	for i in "${!wget_urls[@]}"; do
		wget "${wget_urls[i]}" -q --show-progress -O "${wget_paths[i]}"
	done
}
download() {
	# a wrapper of the function "wget_all"
	if [ ${#wget_urls[@]} = 0 ]; then
		info "No download tasks."
	else
		info "${#wget_urls[@]} files to download:"
		(
			IFS=$'\n'
			echo "${wget_urls[*]}"
		)
		wget_all
	fi
}

# append_to_list CERES_VERSION "http://ceres-solver.org/ceres-solver-${CERES_VERSION}.tar.gz" ""
# append_to_list OPENCV_VERSION "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz" "opencv-${OPENCV_VERSION}.tar.gz"
# append_to_list OPENCV_CONTRIB_VERSION "https://github.com/opencv/opencv_contrib/archive/refs/tags/${OPENCV_CONTRIB_VERSION}.tar.gz" "opencv_contrib-${OPENCV_CONTRIB_VERSION}.tar.gz"
# append_to_list ROS2_DISTRO "https://github.com/ros2/ros2/releases/download/release-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-${OS}-${UBUNTU_DISTRO}-${ARCH}.tar.bz2" ""
# append_to_list CARLA_VERSION "https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz" ""

if [ "${TO_DOWNLOAD}" = true ]; then
	download
else
	warning "TO_DOWNLOAD=false\n\tYou are recommended to leave this option on."
fi

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Downloads >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

info "Done."
