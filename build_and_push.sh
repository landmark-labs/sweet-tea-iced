#!/bin/bash
set -e

# Configuration
DOCKER_USERNAME=${DOCKER_USERNAME:-"jkotieno"}
IMAGE_NAME="comfyui-sweet-tea-cu128"
VERSION="1.0.0"
PLATFORMS="linux/amd64"

echo "Building optimized ComfyUI image..."

# Create and use a buildx builder if not already present
if ! docker buildx inspect sweet_tea_builder > /dev/null 2>&1; then
    docker buildx create --name sweet_tea_builder --use
    docker buildx inspect --bootstrap
fi

# Build and push using buildx
docker buildx build \
    --platform=${PLATFORMS} \
    --build-arg COMFYUI_COMMIT=master \
    --build-arg APP_MANAGER_VERSION=1.2.2 \
    --build-arg CIVITAI_DOWNLOADER_VERSION=2.1.0 \
    --build-arg RELEASE=${VERSION} \
    --cache-from type=registry,ref=${DOCKER_USERNAME}/${IMAGE_NAME}:cache \
    --cache-to type=registry,ref=${DOCKER_USERNAME}/${IMAGE_NAME}:cache,mode=max \
    -t ${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION} \
    -t ${DOCKER_USERNAME}/${IMAGE_NAME}:latest \
    --push \
    .

echo "Done! Image ready."
echo ""
echo "Usage on RunPod:"
echo "1. Image: ${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
echo "2. GPU: Any CUDA 12.8+ compatible GPU"
echo "3. Disk: 50GB+ container, 100GB+ volume"
echo "4. Ports: 3001, 7777, 8888, 8080"