#!/bin/bash

# Ethicrawler Proxy Build Script

set -e

echo "Building Ethicrawler Enforcement Proxy..."

# Create logs directory
mkdir -p logs

# Build Docker image
docker build -t ethicrawler/proxy:latest .

# Tag with version
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
docker tag ethicrawler/proxy:latest ethicrawler/proxy:$VERSION

echo "Build completed successfully!"
echo "Images created:"
echo "  - ethicrawler/proxy:latest"
echo "  - ethicrawler/proxy:$VERSION"

# Check if we should run the container
if [ "$1" = "--run" ]; then
    echo "Starting proxy container..."
    docker-compose up -d
    echo "Proxy is running at http://localhost"
fi