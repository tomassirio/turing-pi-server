#!/bin/bash

# Usage: ./uninstall-services.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICES_DIR="$(dirname "$0")/services"
uninstalled_services=()

echo -e "${BLUE}
+==================================================+
|                                                  |
|      🚀  Turing Pi Cluster Uninstallation  🚀    |
|                                                  |
+==================================================+
${NC}"

for serviceFolder in "$SERVICES_DIR"/*/; do
  serviceName=$(basename "$serviceFolder")

  # Exclude archived and testing directories
  if [ "$serviceName" == "archived" ] || [ "$serviceName" == "testing" ]; then
    echo -e "${YELLOW}⏭️  Skipping $serviceName...${NC}"
    continue
  fi

  echo -e "${BLUE}🗑️  Uninstalling $serviceName...${NC}"
  helm uninstall "$serviceName"
  uninstalled_services+=("$serviceName")
  echo -e "${BLUE}==================================================${NC}"
done

echo -e "${BLUE}
+==================================================+
|                                                  |
|          🎉  Uninstallation Summary  🎉          |
|                                                  |
+==================================================+
${NC}"
echo -e "${GREEN}🗑️  Services Uninstalled:${NC}"
for service in "${uninstalled_services[@]}"; do
  echo -e "${GREEN}  - $service${NC}"
done
echo ""
echo -e "${GREEN}🎉  All services uninstalled successfully!${NC}"