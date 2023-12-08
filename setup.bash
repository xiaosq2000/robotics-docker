#!/bin/bash
# fail on any error 
set -e

################################################################################
############################ environment variables #############################
################################################################################

# flags
TO_BUILD=${1:-true}
WITH_PROXY=${2:-true}

# parent folder of this script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# default path of env-file for Docker Compose 
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
DISPLAY=${DISPLAY}
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=all
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
echo "${RUNTIME_ENV}" >> ${ENV_FILE}
echo -e "Environment variables are saved to ${ENV_FILE}\n" 
# echo "$(<${ENV_FILE )"

################################################################################
################################### download ###################################
################################################################################
#
# TODO: md5 check or something to prevent corruption
#

if [ "${TO_BUILD}" = false ]; then
    echo -e "Make sure the Docker image is ready, since 'TO_BUILD' flag is set 'false'."
    exit
fi

# load varibles from ${ENV_FILE}, ref: https://stackoverflow.com/a/30969768
set -o allexport && source ${ENV_FILE} && set +o allexport

DOWNLOAD_DIR=${SCRIPT_DIR}/downloads && mkdir -p ${DOWNLOAD_DIR}/

wget_urls=()
# ROS2 (binary)
if [ ! -z "${ROS2_DISTRO}" ]; then
    url="https://github.com/ros2/ros2/releases/download/release-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-${OS}-${UBUNTU_DISTRO}-${ARCH}.tar.bz2"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi
# Cmake (source code)
if [ ! -z "${CMAKE_VERSION}" ]; then
    url="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi
# Python (source code)
if [ ! -z "${PYTHON_VERSION}" ]; then
    url="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi
# Eigen (source code)
if [ ! -z "${EIGEN_VERSION}" ]; then
    url="https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_VERSION}/eigen-${EIGEN_VERSION}.tar.bz2"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi
# Ceres solver (source code)
if [ ! -z "${CERES_VERSION}" ]; then
    url="http://ceres-solver.org/ceres-solver-${CERES_VERSION}.tar.gz"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi
# OpenCV (source code)
if [ ! -z "${OPENCV_VERSION}" ]; then
    url="https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi
# Neovim (binary)
if [ ! -z "${NEOVIM_VERSION}" ]; then
    url="https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi
# Tmux (source code)
if [ ! -z "${TMUX_VERSION}" ]; then
    url="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi
# Carla simulator (binary)
if [ ! -z "${CARLA_VERSION}" ]; then 
    url="https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz"
    if [ ! -f "${DOWNLOAD_DIR}/$(basename ${url})" ]; then
        wget_urls+=("${url}")
    fi
fi

echo "${#wget_urls[@]} files to download..." 

for url in "${wget_urls[@]}"; do
    path="${DOWNLOAD_DIR}/$(basename "$url")"
    wget "${url}" -q --show-progress -c -O ${path}
done
