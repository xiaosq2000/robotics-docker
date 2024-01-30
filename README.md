# robotics in docker

A dockerized development environment for robotics research and development.

## Quick Start

### 0. Prerequisites

- [Docker Engine](https://docs.docker.com/engine/)
- [Docker Compose](https://docs.docker.com/compose/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

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
