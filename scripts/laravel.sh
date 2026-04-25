#!/bin/bash
set -e

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

IMAGE_NAME="${DOCKERHUB_USERNAME}/laravel-devcontainer"
PHP_VERSIONS=("8.3-cli" "8.3-apache")
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

  push)
    docker_login
    version="${2:-$DEFAULT_VERSION}"
    platform="${3:-}"
    echo "Pushing php-${version}..."
    if [ -n "$platform" ]; then
      PHP_VERSION="$version" devcontainer build --workspace-folder ${ROOT_DIR}/src/laravel --image-name "${IMAGE_NAME}:php-${version}" --platform "$platform" --push
    else
      PHP_VERSION="$version" devcontainer build --workspace-folder ${ROOT_DIR}/src/laravel --image-name "${IMAGE_NAME}:php-${version}" --push
    fi
    ;;

  push-all)
    docker_login
    for version in "${PHP_VERSIONS[@]}"; do
      echo "Pushing php-${version}..."
      PHP_VERSION="$version" devcontainer build --workspace-folder ${ROOT_DIR}/src/laravel --image-name "${IMAGE_NAME}:php-${version}" --platform "$PLATFORMS" --push
    done
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
    echo "Usage: $0 {build|build-no-cache|push|push-all|up|exec} [php-version] [platform]"
    exit 1
    ;;
esac
