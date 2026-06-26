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
