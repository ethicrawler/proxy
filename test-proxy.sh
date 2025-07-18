#!/bin/bash

# Ethicrawler Proxy Test Script

set -e

echo "Testing Ethicrawler Enforcement Proxy..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Build the proxy image if it doesn't exist
if ! docker images | grep -q ethicrawler/proxy; then
    echo "Building proxy image..."
    ./build.sh
fi

# Start the proxy (detached)
echo "Starting proxy container..."
docker-compose up -d ethicrawler-proxy

# Wait for proxy to be ready
echo "Waiting for proxy to be ready..."
sleep 5

# Test health check
echo "Testing health check..."
if curl -s http://localhost/health | grep -q "healthy"; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
    exit 1
fi

# Test normal request (should pass through)
echo "Testing normal request..."
if curl -s -H "User-Agent: Mozilla/5.0" http://localhost/ > /dev/null; then
    echo "✓ Normal request passed"
else
    echo "✗ Normal request failed"
fi

# Test whitelisted bot (should pass through)
echo "Testing whitelisted bot..."
if curl -s -H "User-Agent: Googlebot/2.1" http://localhost/ > /dev/null; then
    echo "✓ Whitelisted bot passed"
else
    echo "✗ Whitelisted bot failed"
fi

# Test AI bot (should get 402 if enforcement is enabled)
echo "Testing AI bot detection..."
response=$(curl -s -w "%{http_code}" -H "User-Agent: MyAI-Bot/1.0" http://localhost/)
if [[ "$response" == *"402"* ]]; then
    echo "✓ AI bot correctly blocked with 402"
elif [[ "$response" == *"200"* ]]; then
    echo "ℹ AI bot allowed (enforcement may be disabled)"
else
    echo "✗ Unexpected response: $response"
fi

# Test with invalid JWT
echo "Testing invalid JWT..."
response=$(curl -s -w "%{http_code}" -H "User-Agent: MyAI-Bot/1.0" -H "Authorization: Bearer invalid-token" http://localhost/)
if [[ "$response" == *"402"* ]]; then
    echo "✓ Invalid JWT correctly rejected"
else
    echo "ℹ Invalid JWT response: $response"
fi

echo "Basic proxy tests completed!"
echo "To view logs: docker-compose logs ethicrawler-proxy"
echo "To stop: docker-compose down"