#!/bin/bash
# Runs inside the container after it is created.

set -e

npm install -g @devcontainers/cli
curl -fsSL https://claude.ai/install.sh | bash