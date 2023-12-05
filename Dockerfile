# syntax=docker/dockerfile:1
ARG OS=ubuntu:22.04
FROM ${OS} AS common_base

ARG http_proxy 
ARG HTTP_PROXY 
ARG https_proxy
ARG HTTPS_PROXY
ENV http_proxy ${http_proxy}
ENV HTTP_PROXY ${http_proxy}
ENV https_proxy ${http_proxy}
ENV HTTPS_PROXY ${http_proxy}

ARG COMPILE_JOBS=1
ENV COMPILE_JOBS=${COMPILE_JOBS}

ENV DEBIAN_FRONTEND noninteractive

USER root
# basics dependencies
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # locale
    locales \
    # compile
    build-essential \
    # compress
    zip unzip \
    # network
    wget curl net-tools \
    # ssl verification
    openssl libssl-dev gnupg2 dirmngr ca-certificates \
    # editor
    vim \
    # teamwork
    git doxygen \
    # graphics
    libcanberra-gtk-module \
    # python3
    python3-dev python3-pip python3-venv python3-setuptools python3-wheel \
    # x11 client
    libx11-dev libxt-dev libxpm-dev xauth \
    # google c++ dev tools
    libgoogle-glog-dev libgflags-dev \
    # computation 
    libatlas-base-dev libsuitesparse-dev \
    # usb, uvc, v4l 
    usbutils libv4l-dev v4l-utils \
    && rm -rf /var/lib/apt/lists/*
# set up locales
ENV LC_ALL en_US.UTF-8 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

WORKDIR /usr/local/
# build and install cmake (specified version)
ARG CMAKE_VERSION
RUN if [ -z "${CMAKE_VERSION}" ] ; then :; else \
    export CMAKE_SRC_URL=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    wget ${CMAKE_SRC_URL} && \
    tar -xf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./bootstrap -- -DCMAKE_BUILD_TYPE:STRING=Release && \
    make -j ${COMPILE_JOBS} && \
    make install && \
    rm -rf ../cmake-${CMAKE_VERSION}.tar.gz ../cmake-${CMAKE_VERSION} \
    ; fi
# build and install python3 (specified version), 'altinstall' to prevent conflicts
ARG PYTHON3_VERSION
RUN if [ -z "${PYTHON3_VERSION}" ] ; then :; else \
    export PYTHON3_SRC_URL=https://www.python.org/ftp/python/${PYTHON3_VERSION}/Python-${PYTHON3_VERSION}.tar.xz && \
    wget ${PYTHON3_SRC_URL} && \
    tar -xf Python-${PYTHON3_VERSION}.tar.xz && \
    cd Python-${PYTHON3_VERSION} && \
    ./configure --prefix=/usr --enable-shared --enable-optimizations && \
    make -j ${COMPILE_JOBS} && \
    make altinstall && \
    rm -rf ../Python-${PYTHON3_VERSION} ../Python-${PYTHON3_VERSION}.tar.xz \
    ; fi
# build opencv3 (specified version), not installed to prevent conflicts
ARG OPENCV3_VERSION
RUN if [ -z "${OPENCV3_VERSION}" ] ; then :; else \
    export OPENCV3_SRC_URL=https://github.com/opencv/opencv/archive/refs/tags/${OPENCV3_VERSION}.tar.gz && \
    wget ${OPENCV3_SRC_URL} && \
    tar -xf ${OPENCV3_VERSION}.tar.gz && \
    cd opencv-${OPENCV3_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS} && \
    rm -rf ../${OPENCV3_VERSION}.tar.gz \
    ; fi
# build opencv4 (specified version), not installed to prevent conflicts
ARG OPENCV4_VERSION
RUN if [ -z "${OPENCV4_VERSION}" ] ; then :; else \
    export OPENCV4_SRC_URL=https://github.com/opencv/opencv/archive/refs/tags/${OPENCV4_VERSION}.tar.gz && \
    wget ${OPENCV4_SRC_URL} && \
    tar -xf ${OPENCV4_VERSION}.tar.gz && \
    cd opencv-${OPENCV4_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS} && \
    rm -rf ../${OPENCV4_VERSION}.tar.gz \
    ; fi
# build and install eigen
ARG EIGEN_VERSION
RUN if [ -z "${EIGEN_VERSION}" ] ; then :; else \
    export EIGEN_GIT_URL=https://gitlab.com/libeigen/eigen && \ 
    git clone ${EIGEN_GIT_URL} && \
    cd eigen && \
    git checkout ${EIGEN_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS} && \
    cmake --install build && \
    rm -rf ../eigen \
    ; fi
# build and install ceres
ARG CERES_VERSION
RUN if [ -z "${CERES_VERSION}" ] ; then :; else \
    export CERES_GIT_URL=https://github.com/ceres-solver/ceres-solver && \
    git clone ${CERES_GIT_URL} && \
    cd ceres-solver && \
    git checkout ${CERES_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS} && \
    cmake --install build && \
    rm -rf ../ceres-solver \
    ; fi
################################################################################
# download ROS2 via package manager
ARG ROS_DISTRO
ARG ROS_DISTRO_TAG=desktop
RUN if [ -z "${ROS_DISTRO}" ] ; then :; else \
    apt-get update && apt-get install -qy --no-install-recommends \
    software-properties-common curl && \
    add-apt-repository universe && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
    apt-get update && apt-get install -qy --no-install-recommends \
    ros-dev-tools && \
    apt-get update && apt-get upgrade -qy && \
    apt-get update && apt-get install -qy --no-install-recommends \
    ros-${ROS_DISTRO}-${ROS_DISTRO_TAG} \
    && rm -rf /var/lib/apt/lists/* \
    ; fi
# download Gazebo via package manager
ARG GAZEBO_DISTRO
RUN if [ -z "${GAZEBO_DISTRO}" ] ; then :; else \
    wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null && \
    apt-get update && apt-get install -qy --no-install-recommends \
    ${GAZEBO_DISTRO} ros-${ROS_DISTRO}-ros-gz \
    ; fi

################################################################################
########################## personal stuff from now on ##########################
################################################################################

################################################################################
########################### user & shell & terminal ############################
################################################################################
FROM common_base AS user_base
# user
ARG UID 
ARG GID 
ARG USER 
RUN groupadd -g ${GID} ${USER} && \
    useradd -r -m -d /home/${USER} -s /bin/bash -g ${GID} -u ${UID} ${USER}
USER ${USER}
ARG HOME=/home/${USER}
WORKDIR ${HOME}
# shell
SHELL ["/bin/bash", "-c"]
# terminal
ENV TERM=xterm-256color
ENV color_prompt=yes

################################################################################
############################### carla-simulator ################################
################################################################################

ARG CARLA_VERSION
USER root
RUN if [ -z "${CARLA_VERSION}" ] ; then :; else \
    apt-get update && apt-get install -qy --no-install-recommends \
    libsdl2-2.0 xserver-xorg libvulkan1 libomp5 \
    xdg-user-dirs \
    && rm -rf /var/lib/apt/lists/* \
    ; fi
USER ${USER}
# It's hard to achieve a conditional copy in dockerfile. 
# This a temporal work-around to use a parent folder
COPY --chown=${USER}:${USER} downloads/ downloads/
RUN if [ -z "${CARLA_VERSION}" ] ; then :; else \
    mkdir ~/carla && tar -C ~/carla -xf downloads/CARLA_${CARLA_VERSION}.tar.gz && \
    rm -r downloads \
    ; fi

################################################################################
##################################### nvim #####################################
################################################################################
# nvim dependencies
USER root
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # for nvim-telescope better performance
    ripgrep fd-find \
    # many nvim plugins and language servers are based on node-js and distributed via npm
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*
# nvim
USER ${USER}
ARG NEOVIM_VERSION
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz && \
    tar -zxf nvim-linux64.tar.gz && \
    rm nvim-linux64.tar.gz && \
    mv nvim-linux64 ~/nvim
ENV PATH=~/nvim/bin:${PATH}
# nvim plugin manager
RUN git clone --config http.proxy=${http_proxy} --config https.proxy=${https_proxy} --depth 1 \
    https://github.com/wbthomason/packer.nvim \
    ~/.local/share/nvim/site/pack/packer/start/packer.nvim && \
    mkdir -p ${HOME}/.config/nvim
# Pend for fetching plugins and mounting the configurations at runtime, 
# since my setup is always WIP. i.e. only get packer.nvim (vim plugin manager) 
# ready and mkdir $XDG_CONFIG_HOME/nvim

################################################################################
##################################### tmux #####################################
################################################################################
FROM user_base AS tmux_builder
ARG USER 
USER root 
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    apt-get install -qy --no-install-recommends \
    # tmux build time dependencies
    libevent-dev ncurses-dev build-essential bison pkg-config \
    && rm -rf /var/lib/apt/lists/*
USER ${USER}
# build tmux
ARG TMUX_VERSION
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${http_proxy} https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz && \
    tar -zxf tmux-${TMUX_VERSION}.tar.gz && \
    rm tmux-${TMUX_VERSION}.tar.gz && \
    mv tmux-${TMUX_VERSION} tmux && \
    cd tmux && \
    mkdir build && \
    ./configure prefix=~/tmux/build && \
    make -j ${COMPILE_JOBS}

FROM user_base
ARG USER 
USER root
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    apt-get install -qy --no-install-recommends \
    # tmux runtime dependencies
    libevent-core-2.1-7 libncurses6 \
    && rm -rf /var/lib/apt/lists/*
USER ${USER}
ARG HOME=/home/${USER}
ARG TMUX_VERSION
COPY --from=tmux_builder ${HOME}/tmux/build ${HOME}/tmux/build
ENV PATH=~/tmux/build/bin:${PATH}
ENV MANPATH=~/tmux/build/share/man:${MANPATH}
# tmux plugin manager
RUN git clone --config http.proxy=${http_proxy} --config https.proxy=${http_proxy} \
    https://github.com/tmux-plugins/tpm \
    ~/.tmux/plugins/tpm

################################################################################
############################### python workspace ###############################
################################################################################

# # set up and configure a python-venv workspace
# ENV PYTHON3_VENV_WORKSPACE ~/pyvenv_ws
# RUN PYTHON3_VERSION_MAJOR=`echo ${PYTHON3_VERSION} | cut -d. -f1` && \
#     PYTHON3_VERSION_MINOR=`echo ${PYTHON3_VERSION} | cut -d. -f2` && \
#     python${PYTHON3_VERSION_MAJOR}.${PYTHON3_VERSION_MINOR} -m venv ${PYTHON3_VENV_WORKSPACE} && \
#     cd ${PYTHON3_VENV_WORKSPACE} && \
#     source bin/activate && \
#     python3 -m pip install --upgrade --proxy ${http_proxy} \ 
#     autopep8 \
#     cpplint \
#     numpy \
#     pandas \
#     matplotlib \
#     pytransform3d \
#     && \
#     python3 -m pip install --proxy ${http_proxy} evo --upgrade --no-binary evo && \
#     deactivate

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ${HOME}/.bashrc

ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=
ENV DEBIAN_FRONTEND=
