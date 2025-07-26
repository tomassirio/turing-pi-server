#!/bin/bash

# Usage: ./uninstall-services.sh

SERVICES_DIR="$(dirname "$0")/services"

for serviceFolder in "$SERVICES_DIR"/*/; do
  serviceName=$(basename "$serviceFolder")
  echo "Uninstalling $serviceName..."
  helm uninstall "$serviceName"
  echo "---"
done

