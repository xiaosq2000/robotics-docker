#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_FILE_PATH=${SCRIPT_DIR}/.env

ENV=$(cat <<-END

COMPILE_JOBS=8
http_proxy=http://127.0.0.1:1080
https_proxy=https://127.0.0.1:1080
HTTP_PROXY=http://127.0.0.1:1080
HTTPS_PROXY=https://127.0.0.1:1080

OS=ubuntu:22.04

CMAKE_VERSION=3.27.9
PYTHON3_VERSION=3.12.0
OPENCV3_VERSION=3.4.16
OPENCV4_VERSION=4.8.0
EIGEN_VERSION=3.4.0
CERES_VERSION=2.2.0

ROS_DISTRO=humble
ROS_DISTRO_TAG=desktop
GAZEBO_DISTRO=ignition-fortress

USER=${USER}
UID=$(id -u)
GID=$(id -g)
DISPLAY=${DISPLAY}

CARLA_VERSION=0.9.15

NEOVIM_VERSION=0.9.4
TMUX_VERSION=3.3a

END
)

echo "${ENV}" > ${ENV_FILE_PATH}

echo -e "Environment varibles are saved into \n\t${ENV_FILE_PATH}"

CARLA_VERSION=$(awk -F'=' '/^CARLA_VERSION/ { print $2}' ${ENV_FILE_PATH})
if [ -z "${CARLA_VERSION}" ]
    then
        :
    elif [ -f ${SCRIPT_DIR}/downloads/CARLA_${CARLA_VERSION}.tar.gz ]
    then 
        :
    elif [ ! -f ${SCRIPT_DIR}/downloads/CARLA_${CARLA_VERSION}.tar.gz ]
    then 
        echo "Downloading carla-simulator into downloads/CARLA_${CARLA_VERSION}.tar.gz"
        mkdir -p ${SCRIPT_DIR}/downloads/
        wget https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${CARLA_VERSION}.tar.gz -q --show-progress -O downloads/CARLA_${CARLA_VERSION}.tar.gz
fi

echo -e "Ready to build docker image:
\t\$ docker compose build robotics-dev"
