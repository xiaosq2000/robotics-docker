# syntax=docker/dockerfile:1
ARG OS 
ARG ARCH 
ARG BASE_IMAGE
FROM --platform=${OS}/${ARCH} ${BASE_IMAGE} as development_base
# Networking proxies
ARG http_proxy 
ARG HTTP_PROXY 
ARG https_proxy
ARG HTTPS_PROXY
ENV http_proxy ${http_proxy}
ENV HTTP_PROXY ${http_proxy}
ENV https_proxy ${http_proxy}
ENV HTTPS_PROXY ${http_proxy}
# Avoid getting stuck with interactive interfaces when using apt-get
ENV DEBIAN_FRONTEND noninteractive
# Set the basic locale environment variables.
ENV LC_ALL en_US.UTF-8 
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US
# Set the parent directory for all dependencies (not installed).
ARG DEPENDENCIES_DIR=/usr/local
ENV DEPENDENCIES_DIR=${DEPENDENCIES_DIR}
WORKDIR ${DEPENDENCIES_DIR}

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
ARG COMPILE_JOBS=1
ENV COMPILE_JOBS=${COMPILE_JOBS}

# Build OpenCV.
FROM building_base AS building_opencv
ARG OPENCV_VERSION
ADD ./downloads/opencv-${OPENCV_VERSION}.tar.gz .
ARG OPENCV_CONTRIB_VERSION
ADD ./downloads/opencv_contrib-${OPENCV_CONTRIB_VERSION}.tar.gz .
RUN cd opencv-${OPENCV_VERSION} && \
    cmake . -Bbuild \
    -DCMAKE_BUILD_TYPE=Release \
    -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib-${OPENCV_CONTRIB_VERSION}/modules \
    -DBUILD_SHARED_LIBS=ON \
    -DENABLE_PIC=ON \
    -DOPENCV_GENERATE_PKGCONFIG=ON \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_opencv_apps=OFF \
    # CUDA has issues with LTO support 
    # Ref: https://forums.developer.nvidia.com/t/link-time-optimization-with-cuda-on-linux-flto/55530/6
    -DENABLE_LTO=OFF \
    -DOPENCV_IPP_GAUSSIAN_BLUR=ON \
    -DOPENCV_IPP_MEAN=ON \
    -DOPENCV_IPP_MINMAX=ON \
    -DOPENCV_IPP_SUM=ON \
    -DWITH_CUDA=ON \
    -DWITH_V4L=ON \
    -DWITH_FFMPEG=ON \
    -DWITH_TBB=ON \
    -DWITH_OPENMP=ON \
    -DWITH_GTK=ON \
    && cmake --build build -j ${COMPILE_JOBS}

# Build Ceres-solver.
FROM building_base AS building_ceres
ARG CERES_VERSION
ADD ./downloads/ceres-solver-${CERES_VERSION}.tar.gz .
RUN cd ceres-solver-${CERES_VERSION} && \
    cmake . -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j ${COMPILE_JOBS}

FROM development_base as robotics
# Set up a non-root user within the sudo group.
ARG DOCKER_USER 
ARG DOCKER_UID
ARG DOCKER_GID 
ARG DOCKER_HOME=/home/${DOCKER_USER}
RUN groupadd -g ${DOCKER_GID} ${DOCKER_USER} && \
    useradd -r -m -d ${DOCKER_HOME} -s /bin/bash -g ${DOCKER_GID} -u ${DOCKER_UID} -G sudo ${DOCKER_USER} && \
    echo ${DOCKER_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${DOCKER_USER} && \
    chmod 0440 /etc/sudoers.d/${DOCKER_USER}

# Copy ROS2 (fat achieve) and install Gazebo (APT).
ARG ROS2_DISTRO
ARG ROS2_RELEASE_DATE
ARG UBUNTU_DISTRO
ARG ARCH 
ADD --chown=${DOCKER_USER}:${DOCKER_USER} /downloads/ros2-${ROS2_DISTRO}-${ROS2_RELEASE_DATE}-linux-${UBUNTU_DISTRO}-${ARCH}.tar.bz2 .
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
    apt-get update && apt-get install -qy --no-install-recommends \
    python3-rosdep \
    ros-dev-tools \
    ros-${ROS2_DISTRO}-gazebo-ros \
    && rm -rf /var/lib/apt/lists/*

# Copy Ceres solver binaries.
ARG CERES_VERSION
COPY --from=building_ceres --chown=${DOCKER_USER}:${DOCKER_USER} ${DEPENDENCIES_DIR}/ceres-solver-${CERES_VERSION} ceres-solver-${CERES_VERSION}
# Copy OpenCV binaries.
ARG OPENCV_VERSION
COPY --from=building_opencv --chown=${DOCKER_USER}:${DOCKER_USER} ${DEPENDENCIES_DIR}/opencv-${OPENCV_VERSION} opencv-${OPENCV_VERSION}

################################################################################
####################### Personal Development Environment #######################
################################################################################

USER ${DOCKER_USER}
WORKDIR ${DOCKER_HOME}

SHELL ["/bin/bash", "-c"]

RUN sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    wget curl \
    zsh openssh-server \
    # nvim-telescope performance
    ripgrep fd-find \
    && sudo rm -rf /var/lib/apt/lists/*

# Set up ssh server
RUN sudo mkdir -p /var/run/sshd && \
    sudo sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config && \
    sudo sed -i "s/^.*PermitUserEnvironment.*$/PermitUserEnvironment yes/" /etc/ssh/sshd_config

# Utilize rosdep for installing missing ROS dependencies. Be cautious! 
# `rosdep' is designed for non-root users and dependent on a system package manager, i.e., `sudo' and `apt' here.
# However, sudo is not recommended in Docker for many reasons, and a normal routine of `rosdep' fails here.
# It's just a quick-and-dirty solution.
# Ref: https://robotics.stackexchange.com/questions/75642/how-to-run-rosdep-init-and-update-in-dockerfile

ARG RTI_CONNEXT_DDS_VERSION
RUN sudo apt-get update && \
    source ${DEPENDENCIES_DIR}/ros2-linux/setup.bash && \
    sudo -E rosdep init && \
    rosdep update --rosdistro ${ROS2_DISTRO} && \
    # `RTI_NC_LICENSE_ACCEPTED=yes' to escape from interactive interface. 
    RTI_NC_LICENSE_ACCEPTED=yes rosdep install --from-paths ${DEPENDENCIES_DIR}/ros2-linux/share --ignore-src -y --skip-keys "\
    cyclonedds \
    fastcdr \
    fastrtps \
    urdfdom_headers \
    rti-connext-dds-${RTI_CONNEXT_DDS_VERSION} \
    "

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
    install -Dm 755 lazygit ~/.local/bin && \
    rm lazygit.tar.gz lazygit

# Managers and plugins
RUN \
    # Install starship, a cross-shell prompt tool
    sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
    musl-tools \
    && sudo rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* && \
    wget -qO- https://starship.rs/install.sh | sudo sh -s -- --yes --arch x86_64 && \
    # Install oh-my-zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    # Install zsh plugins
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth 1 https://github.com/conda-incubator/conda-zsh-completion ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/conda-zsh-completion && \
    # Install tpm
    git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.local/share/tmux/plugins/tpm && \
    # Install nvm, without modification of shell profiles
    export NVM_DIR=~/.config/nvm && mkdir -p ${NVM_DIR} && \
    PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' && \
    # Load nvm and install the latest lts nodejs
    . "${NVM_DIR}/nvm.sh" && nvm install --lts node

# Dotfiles
ARG DOTFILES_GIT_HASH
RUN cd ~ && \
    git init --initial-branch=main && \
    git checkout -b docker && \
    git remote add origin https://github.com/xiaosq2000/dotfiles && \
    git fetch --all && \
    git reset --hard ${DOTFILES_GIT_HASH}

# Python
RUN \
    # Download the latest pyenv (python version and venv manager)
    curl https://pyenv.run | bash && \
    # Download the latest miniconda
    mkdir -p ~/.local/miniconda3 && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/.local/miniconda.sh && \
    bash ~/.local/miniconda.sh -b -u -p ~/.local/miniconda3 && \
    rm -rf ~/.local/miniconda.sh && \
    # Set up conda and pyenv, without conflicts, Ref: https://stackoverflow.com/a/58045893/11393911
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.zshrc && \
    cd ~/.local/miniconda3/bin && \
    ./conda init zsh && \
    ./conda config --set auto_activate_base false

SHELL ["/usr/bin/zsh", "-ic"]

RUN conda create -y -n pytorch python=3.11 && \
    conda activate pytorch && \
    conda install -y gxx==11.4.0 cudatoolkit==11.7 cudatoolkit-dev==11.7 -c conda-forge && \
    conda install -y pytorch==2.1.2 torchvision==0.16.2 -c pytorch

ENV TERM=xterm-256color

# Clear environment variables exclusively for building to prevent pollution.
ENV DEBIAN_FRONTEND=newt
ENV http_proxy=
ENV HTTP_PROXY=
ENV https_proxy=
ENV HTTPS_PROXY=

# # Python
# RUN \
#     # Download the latest pyenv (python version and venv manager)
#     curl https://pyenv.run | bash && \
#     # Download the latest miniconda
#     mkdir -p ~/.local/miniconda3 && \
#     wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/.local/miniconda.sh && \
#     bash ~/.local/miniconda.sh -b -u -p ~/.local/miniconda3 && \
#     rm -rf ~/.local/miniconda.sh && \
#     # Set up conda and pyenv, without conflicts, Ref: https://stackoverflow.com/a/58045893/11393911
#     echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc && \
#     echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc && \
#     echo 'eval "$(pyenv init -)"' >> ~/.zshrc && \
#     cd ~/.local/miniconda3/bin && \
#     ./conda init zsh && \
#     ./conda config --set auto_activate_base false

# # Build and install a Python via pyenv.
# ARG PYTHON_VERSION
# ARG ARCH 
# RUN export PYENV_ROOT="$HOME/.pyenv" && \
#     export PATH="$PYENV_ROOT/bin:$PATH" && \
#     eval "$(pyenv init -)" && \
#     export PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto --enable-shared" && \
#     if [ "${ARCH}" = "amd64" ]; then export PYTHON_CFLAGS="-march=x86-64 -mtune=generic"; fi && \
#     pyenv install ${PYTHON_VERSION}

# echo "PYENV_VERSION=system source ${DEPENDENCIES_DIR}/ros2-linux/setup.bash" >> ${DOCKER_HOME}/.bashrc

# # Install Pytorch via pip.
# RUN PYENV_VERSION=${PYTHON_VERSION} \
#     if [ "${CUDA_VERSION}" != "11.8.0" ]; then \
#     pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118;\
#     fi

# # Copy pre-built CARLA simulator
# RUN apt-get update && apt-get install -qy --no-install-recommends \
#     # runtime dependencies
#     libsdl2-2.0 xserver-xorg libvulkan1 libomp5 \
#     # Fix the seemingly harmless error, ``sh: 1: xdg-user-dir: not found''
#     xdg-user-dirs \
#     && rm -rf /var/lib/apt/lists/* && \
# ARG CARLA_VERSION
# ADD --chown=${DOCKER_USER}:${DOCKER_USER} downloads/CARLA_${CARLA_VERSION}.tar.gz ${DEPENDENCIES_DIR}/CARLA_${CARLA_VERSION}
