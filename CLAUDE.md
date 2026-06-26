# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo maintains personal devcontainer images published to Docker Hub as `idhavalmehta/laravel-devcontainer`. Currently only a Laravel image exists. Images are built and pushed automatically by GitHub Actions — no manual push workflow exists.

## Local development setup

Open this repo in its own devcontainer (VS Code "Reopen in Container"). The root `.devcontainer/devcontainer.json` provides Docker-in-Docker and installs the devcontainer CLI globally on container creation — no additional setup needed.

Alternatively, install globally on the host:
```bash
npm install -g @devcontainers/cli
```

No `.env` file or Docker Hub credentials are needed for local builds.

## Commands

```bash
make build-laravel PHP_VERSION=8.3-cli            # Build image locally
make build-laravel-no-cache PHP_VERSION=8.3-cli   # Build without cache
make up-laravel PHP_VERSION=8.3-cli               # Start a container locally
make exec-laravel                                 # Shell into the running container
make stop-laravel                                 # Stop the container
make rm-laravel                                   # Remove the container
```

## Architecture

```
src/laravel/
  matrix.json                   # PHP versions and platform/runner pairs used by CI matrix
  .devcontainer/
    Dockerfile                  # ARG VARIANT selects PHP base tag; installs extensions + Composer + Laravel CLI
    devcontainer.json           # Reads PHP_VERSION env var for VARIANT build arg; names container "laravel-devcontainer"

.github/workflows/
  laravel.yaml                  # Three-job pipeline: setup (reads matrix.json) → build (native runners) → merge (assembles manifests)

scripts/
  common.sh                     # Sets SCRIPT_DIR and ROOT_DIR
  laravel.sh                    # Wraps devcontainer build/up/exec for local use

Makefile                        # Thin wrappers around scripts/laravel.sh
```

### CI pipeline

The workflow has three jobs:

1. **`setup`** — reads `matrix.json`, outputs the full matrix object and separate `php_versions` / `arches` arrays
2. **`build`** — matrix of `php × config`; GitHub computes the cross-product natively. Each job runs on its native runner (`ubuntu-latest` for amd64, `ubuntu-24.04-arm` for arm64), calls `devcontainers/ci@v0.3` to build and push a platform-specific intermediate tag (`php-8.3-cli-amd64`, etc.)
3. **`merge`** — assembles multi-arch manifests from intermediate tags using `docker buildx imagetools create`, tags `latest` to the first PHP version, then deletes the intermediate tags via the Docker Hub API

### Adding a new PHP version or platform

Edit `src/laravel/matrix.json` only — no workflow changes needed. For a new platform, add an entry to `config` with the correct `platform`, `runner`, and `arch` values.
