#!/bin/bash

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Arguments >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
TO_BUILD=true
BUILD_WITH_PROXY=true
RUN_WITH_PROXY=true
RUN_WITH_NVIDIA=true
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arguments <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Be safe.
set -euo pipefail
# The parent folder of this script.
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# The default path of 'env_file' for Docker Compose and clear the file.
env_file=${script_dir}/.env && cat /dev/null > ${env_file}

# >>>>>>>>>>>>>>>>>>>>>>>>>> Environment Variables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
buildtime_env=$(cat <<-END

# >>> as 'service.build.args' in docker-compose.yml >>> 
DOCKER_BUILDKIT=1
OS=linux
ARCH=amd64
BASE_IMAGE=ubuntu:22.04
UBUNTU_DISTRO=jammy
COMPILE_JOBS=32
DEPENDENCIES_DIR=/usr/local
ROS2_DISTRO=humble
ROS2_RELEASE_DATE=20240129
RTI_CONNEXT_DDS_VERSION=6.0.1
OPENCV_VERSION=4.8.0
OPENCV_CONTRIB_VERSION=4.8.1
CERES_VERSION=2.2.0
NEOVIM_VERSION=0.9.4
TMUX_GIT_HASH=ea7136f
DOTFILES_GIT_HASH=7177382
# <<< as 'service.build.args' in docker-compose.yml <<< 

END
)
buildtime_proxy_env=$(cat <<-END

BUILDTIME_NETWORK_MODE=host
# >>> as 'service.build.args' in docker-compose.yml >>> 
# http_proxy: \${buildtime_http_proxy}
buildtime_http_proxy=http://127.0.0.1:1080
buildtime_https_proxy=http://127.0.0.1:1080
BUILDTIME_HTTP_PROXY=http://127.0.0.1:1080
BUILDTIME_HTTPS_PROXY=http://127.0.0.1:1080
# <<< as 'service.build.args' in docker-compose.yml <<< 

END
)
runtime_proxy_env=$(cat <<-END

RUNTIME_NETWORK_MODE=bridge
http_proxy=http://host.docker.internal:1080
https_proxy=http://host.docker.internal:1080
HTTP_PROXY=http://host.docker.internal:1080
HTTPS_PROXY=http://host.docker.internal:1080

END
)
user_env=$(cat <<-END

# >>> as 'service.build.args' in docker-compose.yml >>> 
DOCKER_USER=robotics
DOCKER_UID=$(id -u)
DOCKER_GID=$(id -g)
# <<< as 'service.build.args' in docker-compose.yml <<< 

END
)
runtime_env=$(cat <<-END

RUNTIME=runc
DISPLAY=${DISPLAY}
SDL_VIDEODRIVER=x11

END
)
nvidia_runtime_env=$(cat <<-END

RUNTIME=nvidia
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=all
DISPLAY=${DISPLAY}
SDL_VIDEODRIVER=x11

END
)
# <<<<<<<<<<<<<<<<<<<<<<<<<< Environment Variables <<<<<<<<<<<<<<<<<<<<<<<<<<<<<

echo "
################################################################################
############################ Environment Variables #############################
################################################################################
" >> ${env_file}
echo "# The file is managed by 'setup.bash'." >> ${env_file}

# Verify and save the categories of environment variables.
if [ "${TO_BUILD}" = true ]; then
    echo "${buildtime_env}" >> ${env_file}
else
    echo -e "Warning: TO_BUILD=false\n\tMake sure the Docker image is ready."
fi
if [ "${BUILD_WITH_PROXY}" = true ]; then
    echo "${buildtime_proxy_env}" >> ${env_file}
else
    echo -e "Warning: BUILD_WITH_PROXY=false\n\tChinese GFW may corrupt networking in the building stage."
fi
if [ "${RUN_WITH_PROXY}" = true ]; then
    echo "${runtime_proxy_env}" >> ${env_file}
else
    echo -e "Warning: RUN_WITH_PROXY=false\n\tChinese GFW may corrupt networking."
fi
echo "${user_env}" >> ${env_file}
if [ "${RUN_WITH_NVIDIA}" = true ]; then
    echo "${runtime_env}" >> ${env_file}
else
    echo "${nvidia_runtime_env}" >> ${env_file}
fi
echo "
################################################################################
################################################################################
################################################################################
" >> ${env_file}
# Print the env_file to stdout
cat ${env_file}

# Load varibles from ${env_file}. Ref: https://stackoverflow.com/a/30969768
set -o allexport && source ${env_file} && set +o allexport

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Downloads <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# TODO: md5 check or something to prevent corruption.
# No need to download anything since the Docker image is ready.
if [ "${TO_BUILD}" = false ]; then
    exit 0
fi

downloads_dir=${script_dir}/downloads && mkdir -p ${downloads_dir}/

# Two helper functions for downloading.
wget_urls=(); wget_paths=();
append_to_download_list() {
    if [ -z "$(eval echo "\$$1")" ]; then
        return 0;
    fi
    url="$2"
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
download_all() {
    for i in "${!wget_urls[@]}"; do
        wget "${wget_urls[i]}" -q --show-progress -O "${wget_paths[i]}"
    done
}

append_to_download_list CERES_VERSION "http://ceres-solver.org/ceres-solver-${CERES_VERSION}.tar.gz" ""
append_to_download_list OPENCV_VERSION "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz" "opencv-${OPENCV_VERSION}.tar.gz"
append_to_download_list OPENCV_CONTRIB_VERSION "https://github.com/opencv/opencv_contrib/archive/refs/tags/${OPENCV_CONTRIB_VERSION}.tar.gz" "opencv_contrib-${OPENCV_CONTRIB_VERSION}.tar.gz"
append_to_download_list ROS2_DISTRO "https://github.com/ros2/ros2/releases/download/release-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-${OS}-${UBUNTU_DISTRO}-${ARCH}.tar.bz2" ""
# append_to_download_list CARLA_VERSION "https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz" ""

if [ ${#wget_urls[@]} = 0 ]; then
    echo -e "No download tasks. Done."
    exit;
else
    echo -e "${#wget_urls[@]} files to download:"
    (IFS=$'\n'; echo "${wget_urls[*]}")
fi

download_all;
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Downloads >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
