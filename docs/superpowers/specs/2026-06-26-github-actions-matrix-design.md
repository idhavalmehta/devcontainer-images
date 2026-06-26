# GitHub Actions Matrix Build — Design Spec

**Date:** 2026-06-26
**Status:** Approved

## Problem

Images were being built and pushed to Docker Hub manually via Makefile targets. This is error-prone and doesn't scale to multiple PHP versions and platforms. Push access credentials were also required locally.

## Goals

- CI builds and pushes all images automatically on merge to `main`
- Matrix covers multiple PHP versions (`8.3-cli`, `8.3-apache`) and platforms (`linux/amd64`, `linux/arm64`)
- Platform builds run on native GitHub-hosted runners (no QEMU emulation)
- Local workflow retained for building and running images during development — no local push
- Intermediate platform-specific tags cleaned up after multi-arch manifests are assembled

## Workflow Structure

File: `.github/workflows/laravel.yaml`

### Triggers

- `push` to `main` matching paths `src/laravel/**` or `.github/workflows/laravel.yaml`
- `workflow_dispatch`

### Job 1: `build` (matrix)

Matrix produces 4 jobs (2 PHP versions × 2 platforms):

```
matrix:
  php: ["8.3-cli", "8.3-apache"]
  config:
    - { platform: linux/amd64, runner: ubuntu-latest,    arch: amd64 }
    - { platform: linux/arm64, runner: ubuntu-24.04-arm, arch: arm64 }
```

Each job:
1. `actions/checkout@v4`
2. `docker/login-action@v4` (DOCKERHUB_USERNAME + DOCKERHUB_TOKEN secrets)
3. `devcontainers/ci@v0.3` — builds and pushes an intermediate platform-specific tag:
   - `imageName`: `${{ secrets.DOCKERHUB_USERNAME }}/laravel-devcontainer`
   - `imageTag`: `php-${{ matrix.php }}-${{ matrix.config.arch }}`
   - `subFolder`: `src/laravel`
   - `platform`: `${{ matrix.config.platform }}`
   - `push`: `always`
   - env `PHP_VERSION`: `${{ matrix.php }}`

### Job 2: `merge`

`needs: build`, runs on `ubuntu-latest`.

Steps:
1. `docker/login-action@v4`
2. `docker/setup-buildx-action@v3`
3. For each PHP version, assemble multi-arch manifest:
   ```
   docker buildx imagetools create \
     -t <user>/laravel-devcontainer:php-8.3-cli \
     <user>/laravel-devcontainer:php-8.3-cli-amd64 \
     <user>/laravel-devcontainer:php-8.3-cli-arm64
   ```
4. Tag `latest` from the same sources as `php-8.3-cli`
5. Delete intermediate tags via Docker Hub API (`DELETE /v2/repositories/<user>/<repo>/tags/<tag>`)

## Local Build Setup

### Primary: repo devcontainer

The root `.devcontainer/devcontainer.json` has `docker-in-docker` and runs `npm install -g @devcontainers/cli` on container creation. Opening the repo in VS Code ("Reopen in Container") provides the full build environment. All `make build-*`, `make up-*`, `make exec-*` commands work inside the container.

### Alternative: host install

```bash
npm install -g @devcontainers/cli
```

Requires Node.js and Docker on the host. Same make commands apply.

## Makefile Changes

Remove targets that are now CI-only:
- `make login`
- `make push-laravel`
- `make push-all-laravel`

Retain local-only targets:
- `make build-laravel PHP_VERSION=8.3-cli`
- `make build-laravel-no-cache PHP_VERSION=8.3-cli`
- `make up-laravel PHP_VERSION=8.3-cli`
- `make exec-laravel`
- `make stop-laravel`
- `make rm-laravel`

## Scripts Changes

- Remove `push` and `push-all` cases from `scripts/laravel.sh`
- Remove `scripts/login.sh`
- `scripts/common.sh`: remove `docker_login()` and `.env` sourcing (no local credentials needed)

## Secrets

Both required in GitHub repo Settings → Secrets:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

No `.env` file needed locally for builds (only needed if manually running push, which is removed).
