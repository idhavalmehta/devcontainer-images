#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${ROOT_DIR}/.env"

DOCKER_CONFIG_DIR="${ROOT_DIR}/.docker"
PLATFORMS="linux/amd64,linux/arm64"

docker_login() {
  mkdir -p "$DOCKER_CONFIG_DIR"
  echo "$DOCKERHUB_TOKEN" | docker --config "$DOCKER_CONFIG_DIR" login --username "$DOCKERHUB_USERNAME" --password-stdin
  export DOCKER_CONFIG="$DOCKER_CONFIG_DIR"
}
