#!/bin/bash

# Usage: ./deploy-services.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICES_DIR="$(dirname "$0")/services"
deployed_services=()
sops_services=()

echo -e "${BLUE}
+==================================================+
|                                                  |
|        🚀  Turing Pi Cluster Deployment  🚀      |
|                                                  |
+==================================================+
${NC}"

for serviceFolder in "$SERVICES_DIR"/*/; do
  serviceName=$(basename "$serviceFolder")

  # Exclude archived, testing, and library charts
  if [ "$serviceName" == "archived" ] || [ "$serviceName" == "testing" ] || [ "$serviceName" == "common" ]; then
    echo -e "${YELLOW}⏭️  Skipping $serviceName...${NC}"
    continue
  fi

  echo -e "${BLUE}🚢  Deploying $serviceName...${NC}"

  echo -e "${BLUE}📦  Updating dependencies for $serviceName...${NC}"
  helm dependency update --skip-refresh "$serviceFolder"

  if [ -f "$serviceFolder/secrets.yaml" ]; then
    echo -e "${YELLOW}🤫  Found secrets.yaml, deploying with sops...${NC}"
    helm secrets upgrade -i "$serviceName" "$serviceFolder" -f "$serviceFolder/secrets.yaml"
    sops_services+=("$serviceName")
  else
    echo -e "${GREEN}✅  No secrets.yaml found, deploying with standard helm...${NC}"
    helm upgrade -i "$serviceName" "$serviceFolder"
    deployed_services+=("$serviceName")
  fi

  echo -e "${BLUE}==================================================${NC}"
done

echo -e "${BLUE}
+==================================================+
|                                                  |
|            🎉  Deployment Summary  🎉            |
|                                                  |
+==================================================+
${NC}"
echo -e "${GREEN}✅  Standard Services Deployed:${NC}"
for service in "${deployed_services[@]}"; do
  echo -e "${GREEN}  - $service${NC}"
done

echo ""
echo -e "${YELLOW}🤫  Sops-enabled Services Deployed:${NC}"
for service in "${sops_services[@]}"; do
  echo -e "${YELLOW}  - $service${NC}"
done
echo ""
echo -e "${GREEN}🎉  All services deployed successfully!${NC}"
