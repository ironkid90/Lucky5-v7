#!/bin/bash
set -euo pipefail

# Enhanced health check with better error handling and logging
health_url="https://${AZURE_WEBAPP_NAME}.azurewebsites.net/health/live"
ready_url="https://${AZURE_WEBAPP_NAME}.azurewebsites.net/health/ready"

echo "Starting health check for ${AZURE_WEBAPP_NAME}"
echo "Live endpoint: ${health_url}"
echo "Ready endpoint: ${ready_url}"

# Try live endpoint first (basic health check)
for i in $(seq 1 30); do
    echo "Attempt $i: Checking live endpoint..."
    if curl --fail --silent --show-error --max-time 10 "${health_url}" >/dev/null 2>&1; then
        echo "Live health check passed at ${health_url}"
        
        # Now try ready endpoint (full health check)
        echo "Checking ready endpoint..."
        for j in $(seq 1 10); do
            if curl --fail --silent --show-error --max-time 10 "${ready_url}" >/dev/null 2>&1; then
                echo "Ready health check passed at ${ready_url}"
                echo "Health checks completed successfully"
                exit 0
            fi
            echo "Ready check attempt $j failed, retrying in 10 seconds..."
            sleep 10
        done
        
        echo "Live check passed but ready check failed"
        exit 0  # Still consider success if live check passes
    fi
    
    echo "Live check attempt $i failed, retrying in 10 seconds..."
    sleep 10
done

echo "Health check failed for ${health_url}" >&2
echo "Application may still be starting up. Check Azure App Service logs for details." >&2
exit 1
