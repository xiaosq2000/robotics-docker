# syntax=docker/dockerfile:1

ARG OS 
ARG ARCH 
ARG UBUNTU_DISTRO
ARG UBUNTU_RELEASE_DATE

FROM --platform=${OS}/${ARCH} ubuntu:${UBUNTU_DISTRO}-${UBUNTU_RELEASE_DATE} AS common_base

ARG http_proxy 
ARG HTTP_PROXY 
ARG https_proxy
ARG HTTPS_PROXY
ENV http_proxy ${http_proxy}
ENV HTTP_PROXY ${http_proxy}
ENV https_proxy ${http_proxy}
ENV HTTPS_PROXY ${http_proxy}

ENV DEBIAN_FRONTEND noninteractive

ENV LC_ALL en_US.UTF-8 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # utilities for locale
    locales \
    # a handy CLI tool for superuser privilege, not recommended in Docker though.
    sudo \
    # utilities for management of software sources 
    software-properties-common \
    # networking
    wget curl net-tools \
    # utilities for SSL based verification
    gnupg2 dirmngr ca-certificates \
    # (de)compression utilities for 'zip' format
    zip unzip \
    # basic utilities for development
    build-essential cmake \
    # python3
    python3-dev python3-pip python3-venv python3-setuptools python3-wheel \
    # all you needed for x11 client
    xauth \
    # editor, version control system, documentation generator
    vim git doxygen \
    && rm -rf /var/lib/apt/lists/* \
    # set locales
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

FROM common_base AS building_base
WORKDIR /downloads
ARG COMPILE_JOBS=1
ENV COMPILE_JOBS=${COMPILE_JOBS}
FROM building_base AS building_cmake
ARG CMAKE_VERSION
COPY ./downloads/cmake-${CMAKE_VERSION}.tar.gz cmake-${CMAKE_VERSION}.tar.gz
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # Why is SSL needed? cmake can download stuff :)
    libssl-dev \
    && rm -rf /var/lib/apt/lists/* && \
    tar -zxf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./bootstrap -- -DCMAKE_BUILD_TYPE:STRING=Release && \
    make -j ${COMPILE_JOBS}
FROM building_base AS building_opencv
ARG OPENCV_VERSION
COPY ./downloads/${OPENCV_VERSION}.tar.gz ${OPENCV_VERSION}.tar.gz
RUN tar -xf ${OPENCV_VERSION}.tar.gz && \
    cd opencv-${OPENCV_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS}
FROM building_base AS building_eigen
ARG EIGEN_VERSION
COPY ./downloads/eigen-${EIGEN_VERSION}.tar.bz2 eigen-${EIGEN_VERSION}.tar.bz2
RUN tar -jxf eigen-${EIGEN_VERSION}.tar.bz2 && \
    cd eigen-${EIGEN_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS}
FROM building_eigen AS building_ceres
ARG EIGEN_VERSION
COPY --from=building_eigen /downloads/eigen-${EIGEN_VERSION}/ eigen-${EIGEN_VERSION}/
ARG CERES_VERSION
COPY ./downloads/ceres-solver-${CERES_VERSION}.tar.gz ceres-solver-${CERES_VERSION}.tar.gz
RUN apt-get update &&  apt-get install -qy --no-install-recommends \
    libgoogle-glog-dev libgflags-dev \
    libatlas-base-dev libsuitesparse-dev \
    && rm -rf /var/lib/apt/lists/* && \
    tar -zxf ceres-solver-${CERES_VERSION}.tar.gz && \
    cd ceres-solver-${CERES_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release -DEigen_DIR=eigen-${EIGEN_VERSION} && \
    cmake --build build -j ${COMPILE_JOBS}
FROM building_base AS building_tmux
ARG TMUX_VERSION
COPY ./downloads/tmux-${TMUX_VERSION}.tar.gz tmux-${TMUX_VERSION}.tar.gz
RUN apt-get update && apt-get install -qy --no-install-recommends \
    libevent-dev ncurses-dev build-essential bison pkg-config \
    && rm -rf /var/lib/apt/lists/* && \
    tar -zxf tmux-${TMUX_VERSION}.tar.gz && \
    rm tmux-${TMUX_VERSION}.tar.gz && \
    cd tmux-${TMUX_VERSION} && \
    mkdir -p build && \
    ./configure --prefix=/downloads/tmux-${TMUX_VERSION}/build && \
    make -j ${COMPILE_JOBS} && make install
FROM building_base AS building_python
ARG PYTHON_VERSION 
COPY ./downloads/Python-${PYTHON_VERSION}.tar.xz Python-${PYTHON_VERSION}.tar.xz
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # for pip 
    libssl-dev \
    && rm -rf /var/lib/apt/lists/* && \
    tar -xf Python-${PYTHON_VERSION}.tar.xz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --prefix=/usr --enable-shared --enable-optimizations && \
    make -j ${COMPILE_JOBS}

################################################################################
############################### the final stage ################################
################################################################################
FROM common_base AS dev
# shell & terminal
SHELL ["/bin/bash", "-c"]
ENV TERM=xterm-256color
ENV color_prompt=yes
# non-root user
ARG DOCKER_USER 
ARG DOCKER_UID
ARG DOCKER_GID 
ARG DOCKER_HOME=/home/${DOCKER_USER}
RUN groupadd -g ${DOCKER_GID} ${DOCKER_USER} && \
    useradd -r -m -d ${DOCKER_HOME} -s /bin/bash -g ${DOCKER_GID} -u ${DOCKER_UID} -G sudo ${DOCKER_USER} && \
    echo ${DOCKER_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${DOCKER_USER} && \
    chmod 0440 /etc/sudoers.d/${DOCKER_USER}
WORKDIR ${DOCKER_HOME}
# neovim
ARG NEOVIM_VERSION
COPY --chown=${DOCKER_USER}:${DOCKER_USER} ./downloads/nvim-linux64.tar.gz nvim-linux64.tar.gz
RUN apt-get update && apt-get install -qy --no-install-recommends \
    # for nvim-telescope better performance
    ripgrep fd-find \
    && rm -rf /var/lib/apt/lists/* && \
    tar -zxf nvim-linux64.tar.gz && \
    rm nvim-linux64.tar.gz
ENV PATH=${DOCKER_HOME}/nvim-linux64/bin:${PATH}
# tmux
ARG TMUX_VERSION
COPY --from=building_tmux --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/tmux-${TMUX_VERSION}/build/bin tmux-${TMUX_VERSION}/
RUN apt-get update && apt-get install -qy --no-install-recommends \
    libevent-core-2.1-7 libncurses6 \
    && rm -rf /var/lib/apt/lists/*
ENV PATH=${DOCKER_HOME}/tmux-${TMUX_VERSION}:${PATH}
# ROS2
ARG ROS2_DISTRO
ARG ROS2_RELEASE_DATE
ARG UBUNTU_DISTRO
ARG ARCH 
COPY --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-linux-${UBUNTU_DISTRO}-${ARCH}.tar.bz2 ros2-${ROS2_DISTRO}.tar.bz2
RUN mkdir ros2-${ROS2_DISTRO} && \
    tar -jxf ros2-${ROS2_DISTRO}.tar.bz2 -C ros2-${ROS2_DISTRO} && \
    rm ros2-${ROS2_DISTRO}.tar.bz2 && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
    apt-get update && apt-get install -qy --no-install-recommends \
    python3-rosdep \
    ros-dev-tools \
    && rm -rf /var/lib/apt/lists/*
# 'rosdep' is designed for non-root users and dependent on 'sudo', lack of native Docker support.
# A work-around solution, ref: https://robotics.stackexchange.com/questions/75642/how-to-run-rosdep-init-and-update-in-dockerfile
USER ${DOCKER_USER}
RUN sudo -E rosdep init && \
    sudo apt-get update && \
    rosdep update --rosdistro ${ROS2_DISTRO} && \
    rosdep install --rosdistro ${ROS2_DISTRO} --from-paths ros2-${ROS2_DISTRO}/ros2-linux/share --ignore-src -y --skip-keys "\
    cyclonedds \
    fastcdr \
    fastrtps \
    rti-connext-dds-6.0.1 urdfdom_headers \
    "
USER root
# Gazebo (package manager)
ARG GAZEBO_DISTRO
RUN wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null && \
    apt-get update && apt-get install -qy --no-install-recommends \
    ${GAZEBO_DISTRO} ros-${ROS2_DISTRO}-ros-gz
# CARLA simulator
ARG CARLA_VERSION
COPY --chown=${DOCKER_USER}:${DOCKER_USER} downloads/CARLA_${CARLA_VERSION}.tar.gz CARLA_${CARLA_VERSION}.tar.gz
RUN apt-get update && apt-get install -qy --no-install-recommends \
    libsdl2-2.0 xserver-xorg libvulkan1 libomp5 \
    # fix the harmless error: 'sh: 1: xdg-user-dir: not found'
    xdg-user-dirs \
    && rm -rf /var/lib/apt/lists/* && \
    mkdir CARLA_${CARLA_VERSION} && \
    tar -zxf CARLA_${CARLA_VERSION}.tar.gz -C CARLA_${CARLA_VERSION} && \
    rm CARLA_${CARLA_VERSION}.tar.gz
# CMake
ARG CMAKE_VERSION
COPY --from=building_cmake --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/cmake-${CMAKE_VERSION}/ cmake-${CMAKE_VERSION}/
# Eigen
ARG EIGEN_VERSION
COPY --from=building_eigen --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/eigen-${EIGEN_VERSION}/ eigen-${EIGEN_VERSION}/
# Ceres solver
ARG CERES_VERSION
RUN apt-get update && apt-get install -qy --no-install-recommends \
    libgoogle-glog0v5 libgflags2.2 \
    libatlas3-base  libsuitesparse-dev \
    && rm -rf /var/lib/apt/lists/*
COPY --from=building_ceres --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/ceres-solver-${CERES_VERSION}/ ceres-solver-${CERES_VERSION}/
# OpenCV
ARG OPENCV_VERSION
COPY --from=building_opencv --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/opencv-${OPENCV_VERSION}/ opencv-${OPENCV_VERSION}/
RUN apt-get update && apt-get install -qy --no-install-recommends \
    libcanberra-gtk-module \
    && rm -rf /var/lib/apt/lists/*
# Python (altinstall)
ARG PYTHON_VERSION 
COPY --from=building_python --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/Python-${PYTHON_VERSION}/ Python-${PYTHON_VERSION}/
RUN cd Python-${PYTHON_VERSION}/ && \
    make altinstall && \
    rm -r ../Python-${PYTHON_VERSION}/

USER ${DOCKER_USER}

# nodejs via nvm
ARG NVM_VERSION
RUN git config --global http.proxy ${http_proxy} && git config --global https.proxy ${https_proxy} && \
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash && \
    export NVM_DIR="$DOCKER_HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install --lts node && \
    git config --global --unset http.proxy && git config --global --unset https.proxy
# neovim plugin manager
RUN git clone --config http.proxy=${http_proxy} --config https.proxy=${https_proxy} --depth 1 \
    https://github.com/wbthomason/packer.nvim \
    ${DOCKER_HOME}/.local/share/nvim/site/pack/packer/start/packer.nvim
# tmux plugin manager
RUN git clone --config http.proxy=${http_proxy} --config https.proxy=${http_proxy} \
    https://github.com/tmux-plugins/tpm \
    ${DOCKER_HOME}/.tmux/plugins/tpm
# Python virtual workspace
ENV PYTHON_VENV_PATH=${DOCKER_HOME}/python_venv
RUN PYTHON_VERSION_MAJOR=`echo ${PYTHON_VERSION} | cut -d. -f1` && \
    PYTHON_VERSION_MINOR=`echo ${PYTHON_VERSION} | cut -d. -f2` && \
    python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR} -m venv ${PYTHON_VENV_PATH} && \
    source ${PYTHON_VENV_PATH}/bin/activate && \
    python -m pip install --upgrade \ 
    numpy pandas matplotlib \
    pytransform3d evo \
    carla \
    && \
    deactivate
# usbutils libv4l-dev v4l-utils \
ENV DEBIAN_FRONTEND=newt
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=
