# robotics in docker

A dockerized development environment for roboticists.

## Quick Start

### 0. Requirements & Prerequisites

- Install [Docker Engine](https://docs.docker.com/engine/), [Docker Compose](https://docs.docker.com/compose/) and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- Basic familiarity or usage experience with Docker is sufficient.

### 1. Setup

```bash
./setup.bash
```

### 2. Build

```bash
docker compose build
```

### 3. Start

```bash
docker compose up -d 
```

### 4. Use

```bash
docker exec -it robotics_dev bash
```

## Customize

Here are the components that I use personally. 

| Dependency | Version      |
| :---:      | :---:        |
| nvidia     |              |
| ubuntu     | 22.04        |
| ros2       | iron-desktop |
| cmake      | 3.27.7       |
| python3    | 3.12.0       |
| opencv3    | 3.4.16       |
| opencv4    | 4.8.0        |
| eigen      | 3.4.0        |
| ceres      | 2.2.0        |
| neovim     | 0.9.4        |
| tmux       | 3.3a         |

- To modify version, edit `setup.bash`.
- To add new dependencies, make sure to synchronize changes across all three files: `Dockerfile`, `docker-compose.yml`, and `setup.bash`. 

