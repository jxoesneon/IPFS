#!/bin/bash
# Smoke test for the interop infrastructure
# This script verifies that all services are running and can communicate

set -e

echo "=== Interop Infrastructure Smoke Test ==="
echo ""

# Check if docker-compose is running
echo "1. Checking docker-compose status..."
cd "$(dirname "$0")"
if ! docker-compose ps | grep -q "Up"; then
    echo "ERROR: docker-compose services are not running"
    echo "Run: docker-compose up -d"
    exit 1
fi
echo "✓ docker-compose services are running"
echo ""

# Check dart_ipfs health
echo "2. Checking dart_ipfs health..."
if docker-compose exec -T dart_ipfs curl -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "✓ dart_ipfs is healthy"
else
    echo "✗ dart_ipfs health check failed"
    docker-compose logs dart_ipfs
    exit 1
fi
echo ""

# Check kubo health
echo "3. Checking kubo health..."
if docker-compose exec -T kubo ipfs id > /dev/null 2>&1; then
    echo "✓ kubo is healthy"
else
    echo "✗ kubo health check failed"
    docker-compose logs kubo
    exit 1
fi
echo ""

# Check helia health
echo "4. Checking helia health..."
if docker-compose exec -T helia curl -f http://localhost:5001/health > /dev/null 2>&1; then
    echo "✓ helia is healthy"
else
    echo "✗ helia health check failed"
    docker-compose logs helia
    exit 1
fi
echo ""

# Test network connectivity
echo "5. Testing network connectivity..."
if docker-compose exec -T test-runner ping -c 1 dart_ipfs > /dev/null 2>&1; then
    echo "✓ test-runner can reach dart_ipfs"
else
    echo "✗ test-runner cannot reach dart_ipfs"
    exit 1
fi

if docker-compose exec -T test-runner ping -c 1 kubo > /dev/null 2>&1; then
    echo "✓ test-runner can reach kubo"
else
    echo "✗ test-runner cannot reach kubo"
    exit 1
fi

if docker-compose exec -T test-runner ping -c 1 helia > /dev/null 2>&1; then
    echo "✓ test-runner can reach helia"
else
    echo "✗ test-runner cannot reach helia"
    exit 1
fi
echo ""

# Test API endpoints
echo "6. Testing API endpoints..."

# Test Kubo API
if docker-compose exec -T test-runner curl -f http://kubo:5001/api/v0/version > /dev/null 2>&1; then
    echo "✓ Kubo API is accessible"
else
    echo "✗ Kubo API is not accessible"
    exit 1
fi

# Test Helia API
if docker-compose exec -T test-runner curl -f http://helia:5001/api/v0/version > /dev/null 2>&1; then
    echo "✓ Helia API is accessible"
else
    echo "✗ Helia API is not accessible"
    exit 1
fi

# Test dart_ipfs API
if docker-compose exec -T test-runner curl -f http://dart_ipfs:5001/api/v0/version > /dev/null 2>&1; then
    echo "✓ dart_ipfs API is accessible"
else
    echo "✗ dart_ipfs API is not accessible"
    exit 1
fi
echo ""

# Test Helia add/cat
echo "7. Testing Helia add/cat functionality..."
TEST_DATA="smoke-test-$(date +%s)"
ADD_RESULT=$(docker-compose exec -T helia curl -s -X POST -d "$TEST_DATA" http://localhost:5001/api/v0/add)
CID=$(echo "$ADD_RESULT" | grep -o '"Hash":"[^"]*"' | cut -d'"' -f4)

if [ -n "$CID" ]; then
    echo "✓ Helia added data with CID: $CID"
    
    RETRIEVED=$(docker-compose exec -T helia curl -s "http://localhost:5001/api/v0/cat?arg=$CID")
    if [ "$RETRIEVED" = "$TEST_DATA" ]; then
        echo "✓ Helia retrieved data successfully"
    else
        echo "✗ Helia retrieved data mismatch"
        echo "Expected: $TEST_DATA"
        echo "Got: $RETRIEVED"
        exit 1
    fi
else
    echo "✗ Helia add failed"
    echo "Response: $ADD_RESULT"
    exit 1
fi
echo ""

echo "=== All Smoke Tests Passed ==="
echo ""
echo "The interop infrastructure is ready for testing."
echo "Run the Dart tests with:"
echo "  docker-compose exec test-runner dart test test/interop/test/"
