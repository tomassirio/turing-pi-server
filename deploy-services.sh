#!/bin/bash

# Usage: ./deploy-services.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

SERVICES_DIR="$(dirname "$0")/services"
deployed_services=()
sops_services=()
failed_services=()

echo -e "${BLUE}
+==================================================+
|                                                  |
|        🚀  Turing Pi Cluster Deployment  🚀      |
|                                                  |
+==================================================+
${NC}"

echo -e "${BLUE}🔐  Deploying cluster-secrets...${NC}"
helm secrets upgrade -i cluster-secrets "$(dirname "$0")/config/secrets" -f "$(dirname "$0")/config/secrets/secrets.yaml"
echo -e "${BLUE}==================================================${NC}"

for serviceFolder in "$SERVICES_DIR"/*/; do
  serviceName=$(basename "$serviceFolder")

  # Exclude archived, testing, and library charts
  if [ "$serviceName" == "archived" ] || [ "$serviceName" == "testing" ] || [ "$serviceName" == "common" ]; then
    echo -e "${YELLOW}⏭️  Skipping $serviceName...${NC}"
    continue
  fi

  echo -e "${BLUE}🚢  Deploying ${PURPLE}$serviceName${BLUE}...${NC}"

  echo -e "${BLUE}📦  Updating dependencies for ${PURPLE}$serviceName${BLUE}...${NC}"
  helm dependency update --skip-refresh "$serviceFolder"

  GLOBAL_VALUES="$(dirname "$0")/config/global-values.yaml"

  # Special namespace handling for specific services
  NAMESPACE_ARGS=""
  if [ "$serviceName" == "factorio" ]; then
    NAMESPACE_ARGS="--namespace factorio --create-namespace"
    echo -e "${YELLOW}🎮  Deploying factorio to namespace: factorio${NC}"
  fi

  if [ -f "$serviceFolder/secrets.yaml" ]; then
    echo -e "${YELLOW}🤫  Found secrets.yaml, deploying with sops...${NC}"
    if helm secrets upgrade -i "$serviceName" "$serviceFolder" $NAMESPACE_ARGS -f "$GLOBAL_VALUES" -f "$serviceFolder/secrets.yaml"; then
      sops_services+=("$serviceName")
    else
      echo -e "${RED}❌  ERROR: Failed to deploy ${PURPLE}$serviceName${NC}"
      failed_services+=("$serviceName")
    fi
  else
    echo -e "${GREEN}✅  No secrets.yaml found, deploying with standard helm...${NC}"
    if helm upgrade -i "$serviceName" "$serviceFolder" $NAMESPACE_ARGS -f "$GLOBAL_VALUES"; then
      deployed_services+=("$serviceName")
    else
      echo -e "${RED}❌  ERROR: Failed to deploy ${PURPLE}$serviceName${NC}"
      failed_services+=("$serviceName")
    fi
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
  echo -e "${GREEN}  - ${PURPLE}$service${NC}"
done

echo ""
echo -e "${YELLOW}🤫  Sops-enabled Services Deployed:${NC}"
for service in "${sops_services[@]}"; do
  echo -e "${YELLOW}  - ${PURPLE}$service${NC}"
done

if [ ${#failed_services[@]} -gt 0 ]; then
  echo ""
  echo -e "${RED}❌  Failed Services:${NC}"
  for service in "${failed_services[@]}"; do
    echo -e "${RED}  - ${PURPLE}$service${NC}"
  done
  echo ""
  echo -e "${RED}⚠️  Some services failed to deploy!${NC}"
else
  echo ""
  echo -e "${GREEN}🎉  All services deployed successfully!${NC}"
fi
