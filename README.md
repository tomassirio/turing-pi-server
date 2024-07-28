# Turing Pi Server

This repository contains Kubernetes manifests for deploying Sonarr and Plex on a cluster with an NFS-backed persistent storage.

## Setup Instructions

1. Apply storage configurations:
    ```sh
    kubectl apply -f storage/nfs-pv.yaml
    kubectl apply -f storage/nfs-pvc.yaml
    ```

2. Deploy Sonarr:
    ```sh
    kubectl apply -f sonarr/deployment.yaml
    kubectl apply -f sonarr/service.yaml
    kubectl apply -f sonarr/ingress.yaml
    ```

3. Deploy Plex:
    ```sh
    kubectl apply -f plex/deployment.yaml
    kubectl apply -f plex/service.yaml
    kubectl apply -f plex/ingress.yaml
    ```

## Directory Structure

- `sonarr/` contains the deployment, service, and ingress definitions for Sonarr.
- `plex/` contains the deployment, service, and ingress definitions for Plex.
- `storage/` contains the persistent volume (PV) and persistent volume claim (PVC) definitions.
