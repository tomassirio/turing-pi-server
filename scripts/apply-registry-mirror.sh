#!/bin/bash
# Deploys config/registries.yaml to /etc/rancher/k3s/registries.yaml on every
# node and restarts k3s/k3s-agent to pick it up.
#
# NOT run automatically by deploy-services.sh. Restarting k3s briefly disrupts
# every pod on that node, one at a time here, so review config/registries.yaml
# before running this, and run it only after the registry-cache service and
# storage PVs are deployed (`./deploy-services.sh`), so the mirrors are
# actually up when the nodes restart onto them.
#
# Usage: ./apply-registry-mirror.sh

set -e

SSH_USER="pi"
SERVER_HOST="192.168.2.103"
AGENT_HOSTS=(192.168.2.101 192.168.2.102 192.168.2.104 192.168.2.105)
REGISTRIES_FILE="$(dirname "$0")/../config/registries.yaml"

deploy_to_host() {
  local host=$1
  local service=$2
  echo "==> $host ($service)"
  scp "$REGISTRIES_FILE" "$SSH_USER@$host:/tmp/registries.yaml"
  ssh "$SSH_USER@$host" "sudo mv /tmp/registries.yaml /etc/rancher/k3s/registries.yaml && sudo systemctl restart $service"
}

deploy_to_host "$SERVER_HOST" "k3s"
for host in "${AGENT_HOSTS[@]}"; do
  deploy_to_host "$host" "k3s-agent"
done

echo "Done. Verify with: kubectl get nodes"
