# syntax=docker/dockerfile:1
ARG OS
FROM ${OS} AS common_base
ARG http_proxy 
ARG HTTP_PROXY 
ARG https_proxy
ARG HTTPS_PROXY
ENV http_proxy ${http_proxy}
ENV HTTP_PROXY ${http_proxy}
ENV https_proxy ${http_proxy}
ENV HTTPS_PROXY ${http_proxy}
ENV DEBIAN_FRONTEND noninteractive
USER root
# locales
RUN apt-get update && apt-get install -qy --no-install-recommends \
    locales \
    && rm -rf /var/lib/apt/lists/* && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LC_ALL en_US.UTF-8 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US
# ROS2
ARG ROS_DISTRO
ARG ROS_DISTRO_TAG
RUN apt-get update && apt-get install -qy --no-install-recommends \
    software-properties-common curl && \
    add-apt-repository universe && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
    apt-get update && apt-get install -qy --no-install-recommends \
    ros-dev-tools && \
    apt-get update && apt-get upgrade -qy && \
    apt-get update && apt-get install -qy --no-install-recommends \
    ros-${ROS_DISTRO}-${ROS_DISTRO_TAG} \
    && rm -rf /var/lib/apt/lists/*
# basics dependencies
RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # compile
    build-essential \
    # compress
    zip unzip \
    # network
    wget curl net-tools \
    # editor
    vim \
    # teamwork
    git doxygen \
    # graphics
    libcanberra-gtk-module \
    # python3
    python3-dev python3-pip python3-venv python3-setuptools python3-wheel \
    # x11
    libx11-dev libxt-dev libxpm-dev xauth \
    # google c++ dev tools
    libgoogle-glog-dev libgflags-dev \
    # computation 
    libatlas-base-dev libsuitesparse-dev \
    # hardware 
    usbutils libv4l-dev v4l-utils \
    && rm -rf /var/lib/apt/lists/*
ARG COMPILE_JOBS
# build and install cmake
ARG CMAKE_VERSION
ENV CMAKE_VERSION ${CMAKE_VERSION}
ARG CMAKE_SRC_URL=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
RUN wget ${CMAKE_SRC_URL} && \
    tar xvf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./bootstrap -- -DCMAKE_BUILD_TYPE:STRING=Release && \
    make -j ${COMPILE_JOBS} && \
    make install && \
    rm -rf ../cmake-${CMAKE_VERSION}.tar.gz ../cmake-${CMAKE_VERSION}
# build and install python3
ARG PYTHON3_VERSION
ENV PYTHON3_VERSION ${PYTHON3_VERSION}
ARG PYTHON3_SRC_URL=https://www.python.org/ftp/python/${PYTHON3_VERSION}/Python-${PYTHON3_VERSION}.tar.xz
RUN wget ${PYTHON3_SRC_URL} && \
    tar xvf Python-${PYTHON3_VERSION}.tar.xz && \
    cd Python-${PYTHON3_VERSION} && \
    ./configure --prefix=/usr --enable-shared --enable-optimizations && \
    make -j ${COMPILE_JOBS} && \
    make altinstall && \
    rm -rf ../Python-${PYTHON3_VERSION} ../Python-${PYTHON3_VERSION}.tar.xz
# build and install opencv3
ARG OPENCV3_VERSION
ENV OPENCV3_VERSION ${OPENCV3_VERSION}
ARG OPENCV3_SRC_URL=https://github.com/opencv/opencv/archive/refs/tags/${OPENCV3_VERSION}.tar.gz
RUN cd ${HOME} && \ 
    wget ${OPENCV3_SRC_URL} && \
    tar xvf ${OPENCV3_VERSION}.tar.gz && \
    cd opencv-${OPENCV3_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS} && \
    # cmake --install build && \
    # rm -rf ../opencv-${OPENCV3_VERSION} ../${OPENCV3_VERSION}.tar.gz
    rm -rf ../${OPENCV3_VERSION}.tar.gz
# build and install opencv4
ARG OPENCV4_VERSION
ENV OPENCV4_VERSION ${OPENCV4_VERSION}
ARG OPENCV4_SRC_URL=https://github.com/opencv/opencv/archive/refs/tags/${OPENCV4_VERSION}.tar.gz
RUN cd ${HOME} && \ 
    wget ${OPENCV4_SRC_URL} && \
    tar xvf ${OPENCV4_VERSION}.tar.gz && \
    cd opencv-${OPENCV4_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS} && \
    # cmake --install build && \
    # rm -rf ../opencv-${OPENCV4_VERSION} ../${OPENCV4_VERSION}.tar.gz
    rm -rf ../${OPENCV4_VERSION}.tar.gz
# build and install eigen
ARG EIGEN_VERSION
ENV EIGEN_VERSION ${EIGEN_VERSION}
ARG EIGEN_GIT_URL=https://gitlab.com/libeigen/eigen
RUN git clone ${EIGEN_GIT_URL} && \
    cd eigen && \
    git checkout ${EIGEN_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS} && \
    cmake --install build && \
    rm -rf ../eigen
# build and install ceres
ARG CERES_VERSION
ENV CERES_VERSION ${CERES_VERSION}
ARG CERES_GIT_URL=https://github.com/ceres-solver/ceres-solver
RUN git clone ${CERES_GIT_URL} && \
    cd ceres-solver && \
    git checkout ${CERES_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS} && \
    cmake --install build && \
    rm -rf ../ceres-solver
# set up and configure a python-venv workspace
SHELL ["/bin/bash", "-c"]
ENV PYTHON3_VENV_WORKSPACE ${HOME}/pyvenv_ws
RUN PYTHON3_VERSION_MAJOR=`echo ${PYTHON3_VERSION} | cut -d. -f1` && \
    PYTHON3_VERSION_MINOR=`echo ${PYTHON3_VERSION} | cut -d. -f2` && \
    python${PYTHON3_VERSION_MAJOR}.${PYTHON3_VERSION_MINOR} -m venv ${PYTHON3_VENV_WORKSPACE} && \
    cd ${PYTHON3_VENV_WORKSPACE} && \
    source bin/activate && \
    python3 -m pip install --upgrade --proxy ${http_proxy} \ 
    autopep8 \
    cpplint \
    numpy \
    pandas \
    matplotlib \
    pytransform3d \
    && \
    python3 -m pip install --proxy ${http_proxy} evo --upgrade --no-binary evo && \
    deactivate
################################################################################
################################ personal stuff ################################
################################################################################
FROM common_base AS base
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
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ${HOME}/.bashrc
# terminal
ENV TERM=xterm-256color
ENV color_prompt=yes
################################################################################
FROM base AS nvim
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
ARG USER 
USER ${USER}
ARG HOME=/home/${USER}
ARG NEOVIM_VERSION
ARG NEOVIM_BIN_URL=https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} ${NEOVIM_BIN_URL} && \
    tar -zxf nvim-linux64.tar.gz && \
    rm nvim-linux64.tar.gz && \
    mv nvim-linux64 ${HOME}/nvim-${NEOVIM_VERSION}
ENV PATH=${HOME}/nvim-${NEOVIM_VERSION}/bin:${PATH}
# nvim plugin manager
RUN git clone --config http.proxy=${http_proxy} --config https.proxy=${https_proxy} --depth 1 \
    https://github.com/wbthomason/packer.nvim \
    ~/.local/share/nvim/site/pack/packer/start/packer.nvim && \
    mkdir -p ${HOME}/.config/nvim
# pending for fetching plugins and mounting the configurations at runtime, since my setup is always WIP. only get packer.nvim (vim plugin manager) ready and mkdir $XDG_CONFIG_HOME/nvim
################################################################################
FROM nvim AS tmux_build
# tmux dependencies
USER root 
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    libevent-dev ncurses-dev build-essential bison pkg-config \
    && rm -rf /var/lib/apt/lists/*
ARG USER 
USER ${USER}
ARG HOME=/home/${USER}
# build tmux
ARG TMUX_VERSION
ARG TMUX_SRC_URL=https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${http_proxy} ${TMUX_SRC_URL} && \
    tar -zxf tmux-${TMUX_VERSION}.tar.gz && \
    rm tmux-${TMUX_VERSION}.tar.gz && \
    cd tmux-${TMUX_VERSION} && \
    mkdir build && \
    ./configure prefix=${HOME}/tmux-${TMUX_VERSION}/build && \
    make -j ${COMPILE_JOBS} && \
    make install
# tmux runtime dependencies
FROM nvim AS tmux_runtime
USER root
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    libevent-core-2.1-7 libncurses6 \
    && rm -rf /var/lib/apt/lists/*
ARG USER 
USER ${USER}
ARG HOME=/home/${USER}
ARG TMUX_VERSION
COPY --from=tmux_build ${HOME}/tmux-${TMUX_VERSION}/build ${HOME}/tmux-${TMUX_VERSION}/build
ENV PATH=${HOME}/tmux-${TMUX_VERSION}/build/bin:${PATH}
ENV MANPATH=${HOME}/tmux-${TMUX_VERSION}/build/share/man:${MANPATH}
# tmux plugin manager
RUN git clone --config http.proxy=${http_proxy} --config https.proxy=${http_proxy} \
    https://github.com/tmux-plugins/tpm \
    ~/.tmux/plugins/tpm
################################################################################
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=
ENV DEBIAN_FRONTEND=
