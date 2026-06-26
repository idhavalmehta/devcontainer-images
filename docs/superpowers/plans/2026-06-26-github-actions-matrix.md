# GitHub Actions Matrix Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace manual Docker Hub push workflow with GitHub Actions that builds multi-arch images across multiple PHP versions using a native-runner matrix driven by a version-controlled config file.

**Architecture:** A `matrix.json` config file in `src/laravel/` defines PHP versions and platform/runner pairs. A `setup` job reads this file and outputs the matrix; a `build` job consumes it to run one job per PHP×platform combination on native runners; a `merge` job assembles multi-arch manifests and cleans up intermediate tags. Local Makefile commands remain for build/run only — push is CI-only.

**Tech Stack:** GitHub Actions, `devcontainers/ci@v0.3`, `docker/login-action@v4`, `docker/setup-buildx-action@v3`, Docker Hub API, `jq`, bash.

## Global Constraints

- All images target `linux/amd64` and `linux/arm64` platforms
- Native GitHub-hosted runners only — no QEMU emulation
- `latest` tag always points to the same sources as the first entry in the `php` array (`8.3-cli`)
- Intermediate platform-specific tags (`php-<version>-<arch>`) are deleted after manifests are assembled
- No `.env` file or local Docker Hub credentials required for local builds
- GitHub repo secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` must be set for CI to push

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `src/laravel/matrix.json` | Single source of truth for PHP versions and platform/runner pairs |
| Create | `.github/workflows/laravel.yaml` | Three-job CI pipeline: setup → build → merge |
| Modify | `scripts/laravel.sh` | Remove `push` and `push-all` cases |
| Modify | `scripts/common.sh` | Remove `docker_login()` and `.env` sourcing |
| Delete | `scripts/login.sh` | No longer needed |
| Modify | `Makefile` | Remove `login`, `push-laravel`, `push-all-laravel` targets |
| Modify | `README.md` | Remove manual push docs; add local dev setup section |
| Modify | `CLAUDE.md` | Update prerequisites, commands, and architecture sections |

---

### Task 1: Create matrix.json

**Files:**
- Create: `src/laravel/matrix.json`

**Interfaces:**
- Produces: JSON object with keys `php` (string array) and `config` (array of `{platform, runner, arch}` objects), consumed by the workflow's `setup` job

- [ ] **Step 1: Create the file**

```json
{
  "php": ["8.3-cli", "8.3-apache"],
  "config": [
    { "platform": "linux/amd64", "runner": "ubuntu-latest",    "arch": "amd64" },
    { "platform": "linux/arm64", "runner": "ubuntu-24.04-arm", "arch": "arm64" }
  ]
}
```

Save to `src/laravel/matrix.json`.

- [ ] **Step 2: Validate JSON**

```bash
jq . src/laravel/matrix.json
```

Expected: pretty-printed JSON with no errors.

- [ ] **Step 3: Commit**

```bash
git add src/laravel/matrix.json
git commit -m "feat: add matrix.json config for CI build versions and platforms"
```

---

### Task 2: Create GitHub Actions workflow

**Files:**
- Create: `.github/workflows/laravel.yaml`

**Interfaces:**
- Consumes: `src/laravel/matrix.json` (Task 1), GitHub secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
- Produces: Docker Hub images `<user>/laravel-devcontainer:php-<version>` (multi-arch) and `latest`

- [ ] **Step 1: Create the workflow directory**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Write the workflow file**

Save to `.github/workflows/laravel.yaml`:

```yaml
name: laravel

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "src/laravel/**"
      - ".github/workflows/laravel.yaml"

jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.read.outputs.matrix }}
      php_versions: ${{ steps.read.outputs.php_versions }}
      arches: ${{ steps.read.outputs.arches }}
    steps:
      - uses: actions/checkout@v4

      - id: read
        run: |
          matrix=$(cat src/laravel/matrix.json)
          echo "matrix=$matrix" >> $GITHUB_OUTPUT
          echo "php_versions=$(echo "$matrix" | jq -c '.php')" >> $GITHUB_OUTPUT
          echo "arches=$(echo "$matrix" | jq -c '[.config[].arch]')" >> $GITHUB_OUTPUT

  build:
    needs: setup
    runs-on: ${{ matrix.config.runner }}
    strategy:
      matrix: ${{ fromJSON(needs.setup.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v4
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - uses: devcontainers/ci@v0.3
        env:
          PHP_VERSION: ${{ matrix.php }}
        with:
          imageName: ${{ secrets.DOCKERHUB_USERNAME }}/laravel-devcontainer
          imageTag: php-${{ matrix.php }}-${{ matrix.config.arch }}
          subFolder: src/laravel
          platform: ${{ matrix.config.platform }}
          push: always

  merge:
    needs: [setup, build]
    runs-on: ubuntu-latest
    steps:
      - uses: docker/login-action@v4
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - uses: docker/setup-buildx-action@v3

      - name: Create multi-arch manifests
        env:
          DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
          PHP_VERSIONS: ${{ needs.setup.outputs.php_versions }}
          ARCHES: ${{ needs.setup.outputs.arches }}
        run: |
          for version in $(echo "$PHP_VERSIONS" | jq -r '.[]'); do
            sources=""
            for arch in $(echo "$ARCHES" | jq -r '.[]'); do
              sources="$sources ${DOCKERHUB_USERNAME}/laravel-devcontainer:php-${version}-${arch}"
            done
            docker buildx imagetools create \
              -t ${DOCKERHUB_USERNAME}/laravel-devcontainer:php-${version} \
              $sources
          done

      - name: Tag latest
        env:
          DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
          PHP_VERSIONS: ${{ needs.setup.outputs.php_versions }}
          ARCHES: ${{ needs.setup.outputs.arches }}
        run: |
          first_version=$(echo "$PHP_VERSIONS" | jq -r '.[0]')
          sources=""
          for arch in $(echo "$ARCHES" | jq -r '.[]'); do
            sources="$sources ${DOCKERHUB_USERNAME}/laravel-devcontainer:php-${first_version}-${arch}"
          done
          docker buildx imagetools create \
            -t ${DOCKERHUB_USERNAME}/laravel-devcontainer:latest \
            $sources

      - name: Delete intermediate tags
        env:
          DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
          DOCKERHUB_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}
          PHP_VERSIONS: ${{ needs.setup.outputs.php_versions }}
          ARCHES: ${{ needs.setup.outputs.arches }}
        run: |
          token=$(curl -s -X POST "https://hub.docker.com/v2/users/login" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"${DOCKERHUB_USERNAME}\",\"password\":\"${DOCKERHUB_TOKEN}\"}" \
            | jq -r '.token')

          for version in $(echo "$PHP_VERSIONS" | jq -r '.[]'); do
            for arch in $(echo "$ARCHES" | jq -r '.[]'); do
              curl -s -X DELETE \
                -H "Authorization: Bearer ${token}" \
                "https://hub.docker.com/v2/repositories/${DOCKERHUB_USERNAME}/laravel-devcontainer/tags/php-${version}-${arch}/"
            done
          done
```

- [ ] **Step 3: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/laravel.yaml'))" && echo "valid"
```

Expected: prints `valid` with no errors.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/laravel.yaml
git commit -m "feat: add GitHub Actions matrix workflow for laravel devcontainer"
```

---

### Task 3: Clean up scripts and Makefile

**Files:**
- Modify: `scripts/laravel.sh` — remove `push` and `push-all` cases
- Modify: `scripts/common.sh` — remove `docker_login()` and `.env` sourcing
- Delete: `scripts/login.sh`
- Modify: `Makefile` — remove `login`, `push-laravel`, `push-all-laravel`

**Interfaces:**
- Consumes: nothing new
- Produces: updated local tooling with no push-related code

- [ ] **Step 1: Update scripts/laravel.sh**

Replace the full file content with:

```bash
#!/bin/bash
set -e

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

IMAGE_NAME="laravel-devcontainer"
DEFAULT_VERSION="8.3-cli"

case "$1" in
  build)
    version="${2:-$DEFAULT_VERSION}"
    platform="${3:-}"
    echo "Building php-${version}..."
    if [ -n "$platform" ]; then
      PHP_VERSION="$version" devcontainer build --workspace-folder ${ROOT_DIR}/src/laravel --image-name "${IMAGE_NAME}:php-${version}" --platform "$platform"
    else
      PHP_VERSION="$version" devcontainer build --workspace-folder ${ROOT_DIR}/src/laravel --image-name "${IMAGE_NAME}:php-${version}"
    fi
    ;;

  build-no-cache)
    version="${2:-$DEFAULT_VERSION}"
    platform="${3:-}"
    echo "Building php-${version} (no cache)..."
    if [ -n "$platform" ]; then
      PHP_VERSION="$version" devcontainer build --workspace-folder ${ROOT_DIR}/src/laravel --image-name "${IMAGE_NAME}:php-${version}" --platform "$platform" --no-cache
    else
      PHP_VERSION="$version" devcontainer build --workspace-folder ${ROOT_DIR}/src/laravel --image-name "${IMAGE_NAME}:php-${version}" --no-cache
    fi
    ;;

  up)
    version="${2:-$DEFAULT_VERSION}"
    PHP_VERSION="$version" devcontainer up --workspace-folder ${ROOT_DIR}/src/laravel --remove-existing-container
    ;;

  stop)
    docker stop laravel-devcontainer
    ;;

  rm)
    docker rm -f laravel-devcontainer
    ;;

  exec)
    devcontainer exec --workspace-folder ${ROOT_DIR}/src/laravel bash
    ;;

  *)
    echo "Usage: $0 {build|build-no-cache|up|exec|stop|rm} [php-version] [platform]"
    exit 1
    ;;
esac
```

- [ ] **Step 2: Update scripts/common.sh**

Replace the full file content with:

```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
```

- [ ] **Step 3: Delete scripts/login.sh**

```bash
git rm scripts/login.sh
```

- [ ] **Step 4: Update Makefile**

Replace the full file content with:

```makefile
## Laravel
build-laravel:
	./scripts/laravel.sh build $(PHP_VERSION) $(PLATFORM)

build-laravel-no-cache:
	./scripts/laravel.sh build-no-cache $(PHP_VERSION) $(PLATFORM)

up-laravel:
	./scripts/laravel.sh up $(PHP_VERSION)

exec-laravel:
	./scripts/laravel.sh exec

stop-laravel:
	./scripts/laravel.sh stop

rm-laravel:
	./scripts/laravel.sh rm
```

- [ ] **Step 5: Verify the build command still works inside the repo devcontainer**

Open this repo in VS Code ("Reopen in Container") or run `devcontainer up --workspace-folder .` then exec into it. Inside the container run:

```bash
make build-laravel PHP_VERSION=8.3-cli
```

Expected: `devcontainer build` runs and produces a local image `laravel-devcontainer:php-8.3-cli`.

- [ ] **Step 6: Commit**

```bash
git add scripts/laravel.sh scripts/common.sh Makefile
git commit -m "chore: remove push targets from scripts and Makefile — CI handles publishing"
```

---

### Task 4: Update README.md and CLAUDE.md

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Rewrite README.md**

Replace the full file content with:

```markdown
# devcontainer-images

My personal collection of [VS Code devcontainer](https://containers.dev/) images, configured the way I actually use them. The official images for these stacks often lack tools I need day-to-day (like Xdebug for Laravel), so I maintain my own versions and publish them to Docker Hub via GitHub Actions.

## Images

### Laravel

The official Laravel devcontainer doesn't include Xdebug, making step-through debugging impossible out of the box. This image fixes that and adds all the PHP extensions a typical Laravel app needs.

**Tags:**
| Tag | Base |
|---|---|
| `php-8.3-cli` | `php:8.3-cli` |
| `php-8.3-apache` | `php:8.3-apache` |
| `latest` | same as `php-8.3-cli` |

**What's added over the official image:**
- `xdebug` — step-through debugging in VS Code
- `pdo_mysql`, `mysqli` — MySQL support
- `pdo_pgsql`, `pgsql` — PostgreSQL support
- `pdo_sqlsrv`, `sqlsrv` — SQL Server support
- `pcntl`, `intl`, `zip`, `dom`, `fileinfo`, `filter`, `libxml`, `xmlreader`
- Composer + Laravel installer (`laravel` CLI)
- Devcontainer features: `common-utils`, `git`, `node`

**Platforms:** `linux/amd64`, `linux/arm64`

## Using the images

Reference an image in your project's `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Laravel App",
  "image": "idhavalmehta/laravel-devcontainer:php-8.3-cli"
}
```

## Publishing

Images are built and pushed to Docker Hub automatically by GitHub Actions on every push to `main` that touches `src/laravel/**`. The workflow builds all PHP versions and platforms in parallel using native runners, then assembles multi-arch manifests.

To add a new PHP version or platform, edit `src/laravel/matrix.json` and push.

## Local development

Open this repo in VS Code and reopen in the devcontainer — it includes Docker-in-Docker and the devcontainer CLI. Then use:

| Command | Description |
|---|---|
| `make build-laravel PHP_VERSION=8.3-cli` | Build the image locally |
| `make build-laravel-no-cache PHP_VERSION=8.3-cli` | Build without Docker layer cache |
| `make up-laravel PHP_VERSION=8.3-cli` | Start a container locally |
| `make exec-laravel` | Open a shell in the running container |
| `make stop-laravel` | Stop the running container |
| `make rm-laravel` | Remove the container |

Alternatively, install the devcontainer CLI globally on any machine with Docker:

```bash
npm install -g @devcontainers/cli
```
```

- [ ] **Step 2: Rewrite CLAUDE.md**

Replace the full file content with:

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: update README and CLAUDE.md for CI-driven publishing workflow"
```
