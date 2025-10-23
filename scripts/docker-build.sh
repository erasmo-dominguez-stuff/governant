#!/usr/bin/env bash
set -euo pipefail

# Build the repository Docker image using the Dockerfile in /docker
# This script was created to provide a clear wrapper for CI or local use.
# Usage: ./scripts/docker-build.sh [image-name]
# Example: ./scripts/docker-build.sh governant:local

IMAGE_NAME=${1:-governant:local}

echo "Building Docker image ${IMAGE_NAME} using ./docker/Dockerfile"
docker build -t "$IMAGE_NAME" -f docker/Dockerfile .

echo "Docker image $IMAGE_NAME built."
