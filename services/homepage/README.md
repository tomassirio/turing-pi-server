# Homepage Service

This Helm chart deploys [Homepage](https://gethomepage.dev/), a highly customizable application dashboard with integrations for over 100 services.

## Features

- **Kubernetes Integration**: Automatically discovers services and displays cluster metrics
- **Service Widgets**: Displays real-time stats from integrated services
- **RBAC Enabled**: Includes ClusterRole for accessing Kubernetes resources
- **Secure Configuration**: API keys and passwords stored in encrypted secrets using SOPS

## Integrated Services

This deployment includes widgets for the following services:

- **Media Management**: Sonarr, Radarr, Lidarr, Bazarr, Jellyseerr
- **Downloads**: qBittorrent, Prowlarr
- **Monitoring**: Grafana, Prometheus
- **Utilities**: File Browser, Technitium, Homer Dashboard

## Prerequisites

1. Kubernetes cluster with metrics-server installed
2. SOPS for encrypting secrets
3. Existing PVC for config storage (e.g., `nfs-config-pvc`)

## Configuration

### API Keys and Credentials

Before deploying, you need to configure the API keys and credentials in `secrets.yaml`:

1. Edit `secrets.yaml` and replace the placeholder values with actual credentials:
   - API keys from Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Jellyseerr
   - qBittorrent username and password
   - Grafana username and password

2. Encrypt the secrets file using SOPS:
   ```bash
   sops -e -i secrets.yaml
   ```

### Customization

You can customize the deployment by modifying `values.yaml`:

- **Ingress hostname**: Change `ingress.hosts[0].host` to your desired domain
- **Timezone**: Update `env.TZ` to your timezone
- **Resources**: Set CPU and memory limits/requests as needed

## Deployment

### Using the deployment script

The service will be automatically deployed when running:

```bash
./deploy-services.sh
```

### Manual deployment

```bash
# With encrypted secrets
helm secrets upgrade -i homepage ./services/homepage \
  -f config/global-values.yaml \
  -f ./services/homepage/secrets.yaml

# Without secrets (for testing)
helm upgrade -i homepage ./services/homepage \
  -f config/global-values.yaml
```

## Accessing Homepage

Once deployed, access Homepage at: `http://homepage.localhome.com`

## Configuration Files

Homepage uses several configuration files located in the ConfigMap:

- `settings.yaml`: General settings, theme, and layout
- `services.yaml`: Service definitions and widget configurations
- `bookmarks.yaml`: Quick links to external resources
- `widgets.yaml`: Dashboard widgets (Kubernetes stats, search, etc.)
- `kubernetes.yaml`: Kubernetes integration settings

## Security Notes

- Homepage has no built-in authentication
- It's recommended to deploy behind a reverse proxy with authentication
- API keys are stored as Kubernetes secrets and injected as environment variables
- The service account has read-only access to cluster resources

## Troubleshooting

### Check pod logs
```bash
kubectl logs -l app.kubernetes.io/name=homepage
```

### Verify secrets are loaded
```bash
kubectl exec -it homepage-0 -- env | grep HOMEPAGE_VAR
```

### Check service connectivity
```bash
kubectl exec -it homepage-0 -- wget -O- http://sonarr.default.svc.cluster.local
```

## References

- [Homepage Documentation](https://gethomepage.dev/)
- [Kubernetes Integration Guide](https://gethomepage.dev/configs/kubernetes/)
- [Service Widgets](https://gethomepage.dev/widgets/)
