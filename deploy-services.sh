#!/bin/bash

# Usage: ./deploy-services.sh

SERVICES_DIR="$(dirname "$0")/services"

for serviceFolder in "$SERVICES_DIR"/*/; do
  serviceName=$(basename "$serviceFolder")
  echo "Deploying $serviceName from $serviceFolder..."
  helm upgrade -i "$serviceName" "$serviceFolder"
  echo "---"
done
