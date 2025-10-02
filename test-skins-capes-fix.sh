#!/bin/bash

# Test script for SkinsCapesService go.sum fix
# This script tests the Docker build after removing corrupted go.sum

echo "🔧 Testing SkinsCapesService Docker Build Fix"
echo "=============================================="

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not available"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon not running"
    exit 1
fi

echo "✅ Docker is available and running"

# Test build for SkinsCapesService
echo
echo "🏗️  Building SkinsCapesService..."
echo "================================"

cd "$(dirname "$0")"

if docker build -f GoServices/SkinsCapesService/Dockerfile --no-cache -t skins-capes-service:test ./GoServices/SkinsCapesService; then
    echo
    echo "✅ SkinsCapesService build SUCCESSFUL!"
    echo "🎉 GORM dependency issue has been resolved!"

    # Get image size
    image_size=$(docker images skins-capes-service:test --format "table {{.Size}}" | tail -n 1)
    echo "📦 Built image size: $image_size"

    # Cleanup test image
    if docker rmi skins-capes-service:test >/dev/null 2>&1; then
        echo "🧹 Test image cleaned up"
    fi

    echo
    echo "🎯 Next steps:"
    echo "1. Run: docker-compose build --no-cache"
    echo "2. Run: docker-compose up -d"
    echo "3. Test: ./test-deployment.sh"

else
    echo
    echo "❌ SkinsCapesService build FAILED!"
    echo "📋 Check Docker build logs above for details"
    exit 1
fi