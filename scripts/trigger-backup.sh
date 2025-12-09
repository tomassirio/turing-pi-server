#!/bin/bash
# Trigger a manual backup for a service
# Usage: ./trigger-backup.sh <service-name> [namespace]
#
# Examples:
#   ./trigger-backup.sh sonarr
#   ./trigger-backup.sh grafana default
#   ./trigger-backup.sh --all

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVICE=$1
NAMESPACE=${2:-default}

# Services that have backup sidecars
BACKUP_SERVICES=(
    "sonarr"
    "radarr"
    "lidarr"
    "prowlarr"
    "bazarr"
    "jellyseerr"
    "grafana"
    "qbittorrent"
)

trigger_backup() {
    local svc=$1
    local ns=$2

    echo -e "${YELLOW}🔍 Looking for $svc pod in namespace $ns...${NC}"

    # Find the pod
    POD=$(kubectl get pods -n "$ns" -l "app=$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
          kubectl get pods -n "$ns" -l "app.kubernetes.io/name=$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
          kubectl get pods -n "$ns" | grep "^$svc" | head -1 | awk '{print $1}')

    if [ -z "$POD" ]; then
        echo -e "${RED}❌ No pod found for $svc in namespace $ns${NC}"
        return 1
    fi

    echo -e "${GREEN}📦 Found pod: $POD${NC}"

    # Check if backup-config container exists
    if ! kubectl get pod "$POD" -n "$ns" -o jsonpath='{.spec.containers[*].name}' | grep -q "backup-config"; then
        echo -e "${RED}❌ No backup-config sidecar found in pod $POD${NC}"
        return 1
    fi

    echo -e "${YELLOW}🚀 Triggering backup for $svc...${NC}"
    kubectl exec -n "$ns" "$POD" -c backup-config -- touch /tmp/trigger-backup

    echo -e "${GREEN}✅ Backup triggered for $svc! Check logs with:${NC}"
    echo -e "   kubectl logs -n $ns $POD -c backup-config -f"
}

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service-name> [namespace]"
    echo "       $0 --all [namespace]"
    echo ""
    echo "Available services with backup:"
    printf '  - %s\n' "${BACKUP_SERVICES[@]}"
    exit 1
fi

if [ "$SERVICE" == "--all" ]; then
    echo -e "${YELLOW}🔄 Triggering backup for all services...${NC}"
    for svc in "${BACKUP_SERVICES[@]}"; do
        trigger_backup "$svc" "$NAMESPACE" || true
        echo ""
    done
    echo -e "${GREEN}✅ All backups triggered!${NC}"
else
    trigger_backup "$SERVICE" "$NAMESPACE"
fi

