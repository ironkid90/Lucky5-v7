#!/bin/bash
set -euo pipefail

# Simple health check that uses the basic health endpoint
health_url="https://${AZURE_WEBAPP_NAME}.azurewebsites.net/health/simple"

echo "Starting simple health check for ${AZURE_WEBAPP_NAME}"
echo "Health endpoint: ${health_url}"

# Try the simple health endpoint with more retries and longer timeouts
for i in $(seq 1 60); do
    echo "Attempt $i: Checking simple health endpoint..."
    
    if curl --fail --silent --show-error --max-time 30 --connect-timeout 10 "${health_url}" >/dev/null 2>&1; then
        echo "Simple health check passed at ${health_url}"
        echo "Application is responding and ready"
        exit 0
    fi
    
    if [ $i -eq 10 ] || [ $i -eq 30 ] || [ $i -eq 45 ]; then
        echo "Still waiting for application to start... (attempt $i/60)"
    fi
    
    sleep 10
done

echo "Simple health check failed after 60 attempts" >&2
echo "Application may not be starting properly" >&2
echo "Check Azure App Service logs for startup errors" >&2
exit 1
