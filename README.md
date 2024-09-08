# robotics in docker

A dockerized development environment for robotics research and development.

## Quick Start

### 0. Prerequisites

- [Docker Engine](https://docs.docker.com/engine/)
- [Docker Compose](https://docs.docker.com/compose/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

### 1. Setup

```sh
./setup.sh
```

### 2. Build

```sh
docker compose build
```

### 3. Start

```sh
docker compose up -d 
```

### 4. Use

```sh
docker exec -it robotics zsh
```

## Customization

Make sure to synchronize changes across the three files: `Dockerfile`, `docker-compose.yml`, and `setup.sh`.

## Todo

1. A manifest
2. Comments on some tricks
3. Add branches for local and remote usage
