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

## Tips for customization

- Do not modify `.env` directly, modifiy and run `setup.bash` instead.
- If you don't want some dependencies, just leave the value (version) empty.
- Make sure to synchronize changes across the three files: `Dockerfile`, `docker-compose.yml`, and `setup.bash`.
