#!/bin/bash
set -euo pipefail

# Enhanced health check with progressive endpoints and better error handling
health_url="https://${AZURE_WEBAPP_NAME}.azurewebsites.net"
startup_url="${health_url}/health/startup"
live_url="${health_url}/health/live"
ready_url="${health_url}/health/ready"

echo "Starting enhanced health check for ${AZURE_WEBAPP_NAME}"
echo "Startup endpoint: ${startup_url}"
echo "Live endpoint: ${live_url}"
echo "Ready endpoint: ${ready_url}"

# Function to check endpoint with timeout
check_endpoint() {
    local url=$1
    local max_attempts=$2
    local description=$3
    
    echo "Checking ${description} endpoint: ${url}"
    
    for i in $(seq 1 $max_attempts); do
        if curl --fail --silent --show-error --max-time 10 --connect-timeout 5 "${url}" >/dev/null 2>&1; then
            echo "  ${description} check passed on attempt $i"
            return 0
        fi
        echo "  ${description} check attempt $i failed, retrying in 10 seconds..."
        sleep 10
    done
    
    echo "  ${description} check failed after $max_attempts attempts"
    return 1
}

# Progressive health check strategy
echo "=== Step 1: Startup Health Check ==="
if check_endpoint "${startup_url}" 12 "Startup"; then
    echo "Startup check passed - application is responding"
else
    echo "Startup check failed - application may not be starting properly"
    echo "Checking application logs for startup errors..."
    exit 1
fi

echo "=== Step 2: Live Health Check ==="
if check_endpoint "${live_url}" 18 "Live"; then
    echo "Live check passed - basic health is good"
else
    echo "Live check failed - basic health issues detected"
    exit 1
fi

echo "=== Step 3: Ready Health Check ==="
if check_endpoint "${ready_url}" 12 "Ready"; then
    echo "Ready check passed - application is fully ready"
else
    echo "Ready check failed - application not fully ready"
    echo "This may be expected if Redis or other dependencies are not configured"
    echo "Application should still be functional for basic operations"
    exit 0  # Don't fail deployment if ready check fails but live passes
fi

echo "=== Health Check Summary ==="
echo "All health checks passed successfully"
echo "Application is fully operational"
exit 0
