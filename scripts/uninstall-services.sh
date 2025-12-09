#!/bin/bash

# Usage: ./uninstall-services.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

SERVICES_DIR="$(dirname "$0")/services"
uninstalled_services=()
failed_services=()

echo -e "${BLUE}
+==================================================+
|                                                  |
|      🚀  Turing Pi Cluster Uninstallation  🚀    |
|                                                  |
+==================================================+
${NC}"

for serviceFolder in "$SERVICES_DIR"/*/; do
  serviceName=$(basename "$serviceFolder")

  # Exclude archived, testing, and library charts
  if [ "$serviceName" == "archived" ] || [ "$serviceName" == "testing" ] || [ "$serviceName" == "common" ]; then
    echo -e "${YELLOW}⏭️  Skipping ${PURPLE}$serviceName${YELLOW}...${NC}"
    continue
  fi

  echo -e "${BLUE}🗑️  Uninstalling ${PURPLE}$serviceName${BLUE}...${NC}"

  # Special namespace handling for specific services
  NAMESPACE_ARGS=""
  if [ "$serviceName" == "factorio" ]; then
    NAMESPACE_ARGS="--namespace factorio"
    echo -e "${YELLOW}🎮  Uninstalling factorio from namespace: factorio${NC}"
  fi

  if helm uninstall "$serviceName" $NAMESPACE_ARGS 2>/dev/null; then
    uninstalled_services+=("$serviceName")
  else
    echo -e "${RED}❌  ERROR: Failed to uninstall ${PURPLE}$serviceName${RED} (may not exist)${NC}"
    failed_services+=("$serviceName")
  fi

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
  echo -e "${GREEN}  - ${PURPLE}$service${NC}"
done

if [ ${#failed_services[@]} -gt 0 ]; then
  echo ""
  echo -e "${RED}❌  Failed/Not Found Services:${NC}"
  for service in "${failed_services[@]}"; do
    echo -e "${RED}  - ${PURPLE}$service${NC}"
  done
  echo ""
  echo -e "${YELLOW}⚠️  Some services could not be uninstalled (they may not have been installed)${NC}"
else
  echo ""
  echo -e "${GREEN}🎉  All services uninstalled successfully!${NC}"
fi
