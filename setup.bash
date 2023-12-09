#!/bin/bash
# safer bash
# ref: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail
# parent folder of this script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo "Flags: "
TO_BUILD=${1:-true}; echo "TO_BUILD: ${TO_BUILD}"
if [ "${TO_BUILD}" = false ]; then
    echo -e "Make sure the Docker image is ready, since the 'TO_BUILD' flag is set 'false'."
fi
WITH_PROXY=${2:-true}; echo "WITH_PROXY: ${WITH_PROXY}"
WITH_NVIDIA=${3:-true}; echo "WITH_NVIDIA: ${WITH_NVIDIA}"

################################################################################
############################ environment variables #############################
################################################################################

# default path of 'env_file' for Docker Compose && clear the file
ENV_FILE=${SCRIPT_DIR}/.env && cat /dev/null > ${ENV_FILE}
BUILDTIME_ENV=$(cat <<-END
# buildtime
DOCKER_BUILDKIT=1
OS=linux
ARCH=amd64
UBUNTU_DISTRO=jammy
UBUNTU_RELEASE_DATE=20231004
COMPILE_JOBS=8
ROS2_DISTRO=humble
ROS2_RELEASE_DATE=20231122
PYTHON_VERSION=3.8.18
CMAKE_VERSION=3.27.9
OPENCV_VERSION=4.8.0
EIGEN_VERSION=3.4.0
CERES_VERSION=2.2.0
GAZEBO_DISTRO=ignition-fortress
CARLA_VERSION=0.9.15
NEOVIM_VERSION=0.9.4
TMUX_VERSION=3.3a
NVM_VERSION=0.39.7
END
)
PROXY_ENV=$(cat <<-END
# proxy
NETWORK_MODE=host
http_proxy=http://127.0.0.1:1080
https_proxy=http://127.0.0.1:1080
HTTP_PROXY=http://127.0.0.1:1080
HTTPS_PROXY=http://127.0.0.1:1080
END
)
USER_ENV=$(cat <<-END
# user
DOCKER_USER=robotics
DOCKER_UID=$(id -u)
DOCKER_GID=$(id -g)
END
)
RUNTIME_ENV=$(cat <<-END
# runtime
RUNTIME=runc
DISPLAY=${DISPLAY}
SDL_VIDEODRIVER=x11
END
)
NVIDIA_RUNTIME_ENV=$(cat <<-END
# runtime with nvidia
RUNTIME=nvidia
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=all
DISPLAY=${DISPLAY}
SDL_VIDEODRIVER=x11
END
)
if [ "${TO_BUILD}" = true ]; then
    echo "${BUILDTIME_ENV}" >> ${ENV_FILE}
fi
if [ "${WITH_PROXY}" = true ]; then
    echo "${PROXY_ENV}" >> ${ENV_FILE}
fi
echo "${USER_ENV}" >> ${ENV_FILE}
if [ "${WITH_NVIDIA}" = true ]; then
    echo "${NVIDIA_RUNTIME_ENV}" >> ${ENV_FILE}
else
    echo "${RUNTIME_ENV}" >> ${ENV_FILE}
fi
echo -e "\nEnvironment variables are saved to ${ENV_FILE}\n"
# echo "$(<${ENV_FILE )"

################################################################################
################################### download ###################################
################################################################################
#
# TODO: md5 check or something to prevent corruption
#

if [ "${TO_BUILD}" = false ]; then
    exit 0
fi

# load varibles from ${ENV_FILE}
# ref: https://stackoverflow.com/a/30969768
set -o allexport && source ${ENV_FILE} && set +o allexport

DOWNLOAD_DIR=${SCRIPT_DIR}/downloads && mkdir -p ${DOWNLOAD_DIR}/

wget_urls=()
function add_wget_urls () {
    if [ ! -z "$(eval echo "\$$1")" ]; then
        url="$2"
        if [ ! -f "${DOWNLOAD_DIR}/$(basename "$url")" ]; then
            wget_urls+=("$url")
        fi
    fi
}

# source code
add_wget_urls CMAKE_VERSION "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"
add_wget_urls PYTHON_VERSION "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
add_wget_urls EIGEN_VERSION "https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_VERSION}/eigen-${EIGEN_VERSION}.tar.bz2"
add_wget_urls CERES_VERSION "http://ceres-solver.org/ceres-solver-${CERES_VERSION}.tar.gz"
add_wget_urls OPENCV_VERSION "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz"
add_wget_urls TMUX_VERSION "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"

# binary
add_wget_urls ROS2_DISTRO "https://github.com/ros2/ros2/releases/download/release-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-${OS}-${UBUNTU_DISTRO}-${ARCH}.tar.bz2"
add_wget_urls NEOVIM_VERSION "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz"
add_wget_urls CARLA_VERSION "https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz"

if [ ${#wget_urls[@]} = 0 ]; then
    exit 0
else
    echo "${#wget_urls[@]} files to download: "
    (IFS=$'\n'; echo "${wget_urls[*]}")
fi

# Download everything needed
echo ""
for url in "${wget_urls[@]}"; do
    path="${DOWNLOAD_DIR}/$(basename "$url")"
    wget "${url}" -q --show-progress -c -O ${path}
done
