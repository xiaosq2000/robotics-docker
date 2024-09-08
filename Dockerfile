# syntax=docker/dockerfile:1
ARG OS 
ARG ARCH 
ARG BASE_IMAGE
FROM --platform=${OS}/${ARCH} ${BASE_IMAGE} as development_base
# Networking proxies
ARG buildtime_http_proxy 
ARG buildtime_https_proxy
ENV http_proxy ${http_proxy}
ENV https_proxy ${https_proxy}
ENV HTTP_PROXY ${http_proxy}
ENV HTTPS_PROXY ${https_proxy}
# Avoid getting stuck with interactive interfaces when using apt-get
ENV DEBIAN_FRONTEND noninteractive
# Set the basic locale environment variables.
ENV LC_ALL en_US.UTF-8 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US
# Set the parent directory for all dependencies (not installed).
ARG XDG_PREFIX_DIR=/usr/local
ENV XDG_PREFIX_DIR=${XDG_PREFIX_DIR}
WORKDIR ${XDG_PREFIX_DIR}

RUN apt-get update && \
    apt-get install -qy --no-install-recommends \
    # a handy tool for superuser privilege
    sudo \
    # a handy tool to set up locales
    locales \
    # a handy tool to print LSB (Linux Standard Base) and distribution information
    lsb-release \
    # essentials for building
    build-essential pkg-config cmake \
    # compression
    zip unzip zlib1g-dev liblzma-dev libbz2-dev \
    # networking
    wget curl net-tools \
    # SSL based verification
    gnupg2 dirmngr ca-certificates libssl-dev \
    # management of software sources 
    software-properties-common \
    # editor, version control system, documentation generator, manual, bash completion
    vim git doxygen man-db bash-completion \
    # x11 client 
    xauth xclip x11-apps \
    # ssh server 
    openssh-server \
    # desktop-bus
    dbus dbus-x11 \
    # text-based user interfaces 
    libreadline-dev ncurses-dev libffi-dev \
    # graphics user interfaces
    tk-dev libgtk-3-dev libcanberra-gtk3-module \
    # image codec
    libpng-dev libjpeg-dev libtiff-dev libopenjp2-7-dev \
    # ffmpeg
    libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev libavutil-dev libpostproc-dev libswscale-dev \
    # kernel headers, here for v4l for opencv
    linux-headers-generic \
    # usb peripherals & uvc cameras
    usbutils libv4l-dev v4l-utils \
    # python3
    python3-dev python3-pip python3-venv python3-setuptools python3-wheel \
    # linear algebra libraries
    libeigen3-dev libatlas-base-dev libblas-dev liblapack-dev libsuitesparse-dev \
    # logging and cli flag libraries
    libgoogle-glog-dev libgflags-dev \
    # cpu acceleration libraries
    libbtbb-dev libomp-dev \
    # opengl math
    libglm-dev \
    # sql
    libsqlite3-dev \
    # Clear
    && rm -rf /var/lib/apt/lists/* && \
    # Set locales
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

FROM development_base AS building_base
ARG COMPILE_JOBS
FROM development_base as robotics
# Set up a non-root user within the sudo group.
ARG DOCKER_USER 
ARG DOCKER_UID
ARG DOCKER_GID 
ARG DOCKER_HOME
RUN groupadd -g ${DOCKER_GID} ${DOCKER_USER} && \
    useradd -r -m -d ${DOCKER_HOME} -s /bin/bash -g ${DOCKER_GID} -u ${DOCKER_UID} -G sudo ${DOCKER_USER} && \
    echo ${DOCKER_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${DOCKER_USER} && \
    chmod 0440 /etc/sudoers.d/${DOCKER_USER}

################################################################################
####################### Personal Development Environment #######################
################################################################################

USER ${DOCKER_USER}
WORKDIR ${DOCKER_HOME}

SHELL ["/bin/bash", "-c"]

ENV XDG_DATA_HOME=${DOCKER_HOME}/.local/share
ENV XDG_CONFIG_HOME=${DOCKER_HOME}/.config
ENV XDG_STATE_HOME=${DOCKER_HOME}/.local/state
ENV XDG_CACHE_HOME=${DOCKER_HOME}/.cache
ENV XDG_PREFIX_HOME=${DOCKER_HOME}/.local

# TODO: Manually build and install without sudo privilege
RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    lsb-release \
    wget curl \
    zsh direnv \
    python3-venv python3-pip \
    openssh-server \
    ripgrep fd-find \
    && sudo rm -rf /var/lib/apt/lists/*

ARG ROS_DISTRO
RUN sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add - && \
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    ros-${ROS_DISTRO}-desktop-full \
    python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool build-essential \
    && sudo rm -rf /var/lib/apt/lists/* \
    sudo rosdep init
# ref: https://answers.ros.org/question/284683/rosdep-update-error-in-kinetic/
RUN if [ -z "${http_proxy}" ]; then unset http_proxy && unset https_proxy && unset HTTP_PROXY && unset HTTPS_PROXY; fi && \
    source /opt/ros/${ROS_DISTRO}/setup.bash && \
    sudo rosdep init && \
    sudo apt update && \
    rosdep update

# Set up ssh server
RUN sudo mkdir -p /var/run/sshd && \
    sudo sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config && \
    sudo sed -i "s/^.*PermitUserEnvironment.*$/PermitUserEnvironment yes/" /etc/ssh/sshd_config

# Neovim
ARG NEOVIM_VERSION
RUN wget "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux64.tar.gz" -O nvim-linux64.tar.gz && \
    tar -xf nvim-linux64.tar.gz && \
    export SOURCE_DIR=${PWD}/nvim-linux64 && export DEST_DIR=${HOME}/.local && \
    (cd ${SOURCE_DIR} && find . -type f -exec install -Dm 755 "{}" "${DEST_DIR}/{}" \;) && \
    rm -r nvim-linux64.tar.gz nvim-linux64

# Tmux
ARG TMUX_GIT_HASH
RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    libevent-dev ncurses-dev build-essential bison pkg-config autoconf automake \
    && sudo rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* && \
    git clone "https://github.com/tmux/tmux" && cd tmux && \
    git checkout ${TMUX_GIT_HASH} && \
    sh autogen.sh && \
    ./configure --prefix=${DOCKER_HOME}/.local && \
    make -j ${COMPILE_JOBS} && \
    make install && \
    rm -rf ../tmux

# Lazygit (newest version)
RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') && \
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
    tar xf lazygit.tar.gz lazygit && \
    install -Dm 755 lazygit ${XDG_PREFIX_HOME}/bin && \
    rm lazygit.tar.gz lazygit

RUN \
    # Install starship, a cross-shell prompt tool
    mkdir -p ${XDG_PREFIX_HOME}/bin && \
    wget -qO- https://starship.rs/install.sh | sh -s -- --yes -b ${XDG_PREFIX_HOME}/bin && \
    # Install oh-my-zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    # Install tpm
    if [ -n ${http_proxy} && -n ${https_proxy} ]; then \
    git clone --config http.proxy=${http_proxy} --config https.proxy=${https_proxy} --depth 1 https://github.com/tmux-plugins/tpm ${XDG_PREFIX_HOME}/share/tmux/plugins/tpm; \
    else \
    git clone --depth 1 https://github.com/tmux-plugins/tpm ${XDG_PREFIX_HOME}/share/tmux/plugins/tpm; \
    fi && \
    # Install nvm, without modification of shell profiles
    export NVM_DIR=~/.config/nvm && mkdir -p ${NVM_DIR} && \
    PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' && \
    # Load nvm and install the latest lts nodejs
    . "${NVM_DIR}/nvm.sh" && nvm install --lts node

# Micromamba (For Linux Intel (x86_64))
RUN cd ${XDG_PREFIX_HOME} && \
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba

# A trick to get rid of using Docker building cache from now on.
ARG SETUP_TIMESTAMP

# Dotfiles
RUN cd ~ && \
    git init && \
    # git branch -M main && \
    git remote add origin https://github.com/xiaosq2000/dotfiles && \
    git fetch --all && \
    git reset --hard origin/main

ENV TERM=xterm-256color
SHELL ["/usr/bin/zsh", "-ic"]
RUN sudo chsh -s /usr/bin/zsh

RUN micromamba config append channels conda-forge && \
    micromamba config set channel_priority strict

# Clear environment variables exclusively for building to prevent pollution.
ENV DEBIAN_FRONTEND=newt
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=

CMD [ "zsh" ]
################################################################################
################################### Archive ####################################
################################################################################

# # Copy ROS2 (fat achieve) and install Gazebo (APT).
# ARG ROS2_DISTRO
# ARG ROS2_RELEASE_DATE
# ARG UBUNTU_DISTRO
# ARG ARCH 
# ADD --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-linux-${UBUNTU_DISTRO}-${ARCH}.tar.bz2 .
# RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
#     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
#     apt-get update && apt-get install -qy --no-install-recommends \
#     python3-rosdep \
#     ros-dev-tools \
#     ros-${ROS2_DISTRO}-gazebo-ros \
#     && rm -rf /var/lib/apt/lists/*

# # Utilize rosdep for installing missing ROS dependencies. Be cautious! 
# # `rosdep' is designed for non-root users and dependent on a system package manager, i.e., `sudo' and `apt' here.
# # However, sudo is not recommended in Docker for many reasons, and a normal routine of `rosdep' fails here.
# # It's just a quick-and-dirty solution.
# # Ref: https://robotics.stackexchange.com/questions/75642/how-to-run-rosdep-init-and-update-in-dockerfile
# 
# ARG RTI_CONNEXT_DDS_VERSION
# RUN sudo apt-get update && \
#     source ${XDG_PREFIX_DIR}/ros2-linux/setup.bash && \
#     sudo -E rosdep init && \
#     rosdep update --rosdistro ${ROS2_DISTRO} && \
#     # `RTI_NC_LICENSE_ACCEPTED=yes' to escape from interactive interface. 
#     RTI_NC_LICENSE_ACCEPTED=yes rosdep install --from-paths ${XDG_PREFIX_DIR}/ros2-linux/share --ignore-src -y --skip-keys "\
#     cyclonedds \
#     fastcdr \
#     fastrtps \
#     urdfdom_headers \
#     rti-connext-dds-${RTI_CONNEXT_DDS_VERSION} \
#     "
# # Build OpenCV.
# FROM building_base AS building_opencv
# ARG OPENCV_VERSION
# ADD ./downloads/opencv-${OPENCV_VERSION}.tar.gz .
# ARG OPENCV_CONTRIB_VERSION
# ADD ./downloads/opencv_contrib-${OPENCV_CONTRIB_VERSION}.tar.gz .
# RUN cd opencv-${OPENCV_VERSION} && \
#     cmake . -Bbuild \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib-${OPENCV_CONTRIB_VERSION}/modules \
#     -DBUILD_SHARED_LIBS=ON \
#     -DENABLE_PIC=ON \
#     -DOPENCV_GENERATE_PKGCONFIG=ON \
#     -DBUILD_TESTS=OFF \
#     -DBUILD_PERF_TESTS=OFF \
#     -DBUILD_EXAMPLES=OFF \
#     -DBUILD_opencv_apps=OFF \
#     # CUDA has issues with LTO support 
#     # Ref: https://forums.developer.nvidia.com/t/link-time-optimization-with-cuda-on-linux-flto/55530/6
#     -DENABLE_LTO=OFF \
#     -DOPENCV_IPP_GAUSSIAN_BLUR=ON \
#     -DOPENCV_IPP_MEAN=ON \
#     -DOPENCV_IPP_MINMAX=ON \
#     -DOPENCV_IPP_SUM=ON \
#     -DWITH_CUDA=ON \
#     -DWITH_V4L=ON \
#     -DWITH_FFMPEG=ON \
#     -DWITH_TBB=ON \
#     -DWITH_OPENMP=ON \
#     -DWITH_GTK=ON \
#     && cmake --build build -j ${COMPILE_JOBS}

# # Build Ceres-solver.
# FROM building_base AS building_ceres
# ARG CERES_VERSION
# ADD ./downloads/ceres-solver-${CERES_VERSION}.tar.gz .
# RUN cd ceres-solver-${CERES_VERSION} && \
#     cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
#     cmake --build build -j ${COMPILE_JOBS}

# # Copy Ceres solver binaries.
# ARG CERES_VERSION
# COPY --from=building_ceres --chown=${DOCKER_USER}:${DOCKER_USER} ${XDG_PREFIX_DIR}/ceres-solver-${CERES_VERSION} ceres-solver-${CERES_VERSION}
# # Copy OpenCV binaries.
# ARG OPENCV_VERSION
# COPY --from=building_opencv --chown=${DOCKER_USER}:${DOCKER_USER} ${XDG_PREFIX_DIR}/opencv-${OPENCV_VERSION} opencv-${OPENCV_VERSION}
# # Copy pre-built CARLA simulator
# RUN apt-get update && apt-get install -qy --no-install-recommends \
#     # runtime dependencies
#     libsdl2-2.0 xserver-xorg libvulkan1 libomp5 \
#     # Fix the seemingly harmless error, ``sh: 1: xdg-user-dir: not found''
#     xdg-user-dirs \
#     && rm -rf /var/lib/apt/lists/* && \
# ARG CARLA_VERSION
# ADD --chown=${DOCKER_USER}:${DOCKER_USER} downloads/CARLA_${CARLA_VERSION}.tar.gz ${XDG_PREFIX_DIR}/CARLA_${CARLA_VERSION}
