# Homepage Service Setup Guide

This guide walks you through setting up the Homepage dashboard with all service integrations.

## Prerequisites

Before deploying Homepage, ensure you have:

1. **SOPS** installed for managing encrypted secrets
2. **Age key** configured (referenced in `.sops.yaml` in the repository root)
3. Access to your services to retrieve API keys

## Step 1: Gather API Keys and Credentials

You need to collect API keys and credentials from each service:

### Sonarr API Key
1. Open Sonarr web UI: `http://sonarr.localhome.com`
2. Go to Settings → General
3. Scroll down to "Security" section
4. Copy the "API Key"

### Radarr API Key
1. Open Radarr web UI: `http://radarr.localhome.com`
2. Go to Settings → General
3. Scroll down to "Security" section
4. Copy the "API Key"

### Lidarr API Key
1. Open Lidarr web UI: `http://lidarr.localhome.com`
2. Go to Settings → General
3. Scroll down to "Security" section
4. Copy the "API Key"

### Bazarr API Key
1. Open Bazarr web UI: `http://bazarr.localhome.com`
2. Go to Settings → General
3. Scroll down to "Security" section
4. Copy the "API Key"

### Prowlarr API Key
1. Open Prowlarr web UI: `http://prowlarr.localhome.com`
2. Go to Settings → General
3. Scroll down to "Security" section
4. Copy the "API Key"

### Jellyseerr API Key
1. Open Jellyseerr web UI: `http://jellyseerr.localhome.com`
2. Go to Settings → General
3. Under "API Key", generate or copy the existing key

### qBittorrent Credentials
1. Note down your qBittorrent username (default is usually `admin`)
2. Note down your qBittorrent password

### Grafana Credentials
1. Note down your Grafana admin username (default is `admin`)
2. Note down your Grafana admin password

## Step 2: Configure secrets.yaml

1. Navigate to the homepage service directory:
   ```bash
   cd services/homepage
   ```

2. Edit the `secrets.yaml` file:
   ```bash
   # Use your preferred editor
   nano secrets.yaml
   # or
   vim secrets.yaml
   ```

3. Replace the placeholder values with your actual credentials:
   ```yaml
   secrets:
     homepage:
       data:
         sonarrApiKey: "your-actual-sonarr-api-key"
         radarrApiKey: "your-actual-radarr-api-key"
         lidarrApiKey: "your-actual-lidarr-api-key"
         bazarrApiKey: "your-actual-bazarr-api-key"
         prowlarrApiKey: "your-actual-prowlarr-api-key"
         jellyseerrApiKey: "your-actual-jellyseerr-api-key"
         qbittorrentUsername: "your-qbittorrent-username"
         qbittorrentPassword: "your-qbittorrent-password"
         grafanaUsername: "your-grafana-username"
         grafanaPassword: "your-grafana-password"
   ```

## Step 3: Encrypt the Secrets with SOPS

Once you've added all the credentials, encrypt the file:

```bash
sops -e -i secrets.yaml
```

This command will:
- Encrypt the sensitive values (API keys, passwords)
- Keep the file structure readable
- Use the age key specified in `.sops.yaml`

After encryption, the file will look like:
```yaml
secrets:
    homepage:
        data:
            sonarrApiKey: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
            radarrApiKey: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
            # ... encrypted values
sops:
    # ... SOPS metadata
```

## Step 4: Verify Encryption

To verify the secrets are encrypted correctly:

```bash
# View the encrypted file
cat secrets.yaml

# Decrypt and view (without modifying the file)
sops -d secrets.yaml
```

## Step 5: Deploy Homepage

### Option A: Deploy All Services (Recommended)

From the repository root:
```bash
./deploy-services.sh
```

This will deploy all services including homepage.

### Option B: Deploy Only Homepage

```bash
cd /path/to/turing-pi-server

# Deploy with encrypted secrets
helm secrets upgrade -i homepage ./services/homepage \
  -f config/global-values.yaml \
  -f ./services/homepage/secrets.yaml
```

## Step 6: Verify Deployment

1. Check if the pod is running:
   ```bash
   kubectl get pods -l app.kubernetes.io/name=homepage
   ```

2. Check the logs:
   ```bash
   kubectl logs -l app.kubernetes.io/name=homepage
   ```

3. Verify secrets are loaded:
   ```bash
   kubectl exec -it homepage-0 -- env | grep HOMEPAGE_VAR
   ```
   
   You should see environment variables like:
   ```
   HOMEPAGE_VAR_SONARR_API_KEY=***
   HOMEPAGE_VAR_RADARR_API_KEY=***
   ```

4. Access the dashboard:
   ```
   http://homepage.localhome.com
   ```

## Step 7: Verify Service Integration

Once Homepage is running:

1. Open `http://homepage.localhome.com` in your browser
2. Check that each service widget displays stats:
   - **Sonarr**: Should show series count, queue status
   - **Radarr**: Should show movie count, queue status
   - **Lidarr**: Should show album/artist count
   - **qBittorrent**: Should show download/upload rates
   - **Prowlarr**: Should show indexer count
   - **Jellyseerr**: Should show request counts
   - **Grafana**: Should show version info

If a widget shows an error:
- Check the API key is correct
- Verify the service URL is accessible from the homepage pod
- Check the service logs for authentication errors

## Updating Secrets

If you need to update any API keys or credentials:

1. Decrypt the secrets file:
   ```bash
   cd services/homepage
   sops secrets.yaml
   ```
   This opens the file in your default editor with decrypted values.

2. Make your changes and save

3. The file is automatically re-encrypted when you close the editor

4. Redeploy homepage:
   ```bash
   helm secrets upgrade -i homepage ./services/homepage \
     -f ../../config/global-values.yaml \
     -f ./secrets.yaml
   ```

## Customization

### Changing Service URLs

If your services use different namespaces or service names, edit `templates/configmap.yaml`:

```yaml
widget:
  type: sonarr
  url: http://sonarr.your-namespace.svc.cluster.local  # Change namespace
  key: {{`{{HOMEPAGE_VAR_SONARR_API_KEY}}`}}
```

### Adding More Services

To add additional services:

1. Add a new entry in `templates/configmap.yaml` under `services.yaml`
2. If the service needs credentials, add them to `secrets.yaml`
3. Add corresponding secret reference in `templates/secret.yaml`
4. Re-encrypt and redeploy

## Troubleshooting

### Widgets Not Showing Data

1. **Check API keys are correct**:
   ```bash
   # Test Sonarr API manually
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl http://sonarr.default.svc.cluster.local/api/v3/system/status \
     -H "X-Api-Key: YOUR_API_KEY"
   ```

2. **Check service connectivity**:
   ```bash
   kubectl exec -it homepage-0 -- wget -O- http://sonarr.default.svc.cluster.local
   ```

3. **Check pod logs for errors**:
   ```bash
   kubectl logs -l app.kubernetes.io/name=homepage --tail=100
   ```

### Permission Errors

If you see Kubernetes permission errors:
- Verify the ClusterRole and ClusterRoleBinding are created
- Check RBAC is enabled in your cluster

### SOPS Decryption Errors

If deployment fails with SOPS errors:
- Verify the age key is correctly configured
- Check `.sops.yaml` has the correct age recipient
- Ensure `helm-secrets` plugin is installed: `helm plugin install https://github.com/jkroepke/helm-secrets`

## Security Best Practices

1. **Never commit unencrypted secrets** to version control
2. **Rotate API keys regularly** for better security
3. **Use separate service accounts** with minimal permissions for each service
4. **Deploy Homepage behind authentication** (e.g., Authelia, Authentik) or within a VPN
5. **Regular backups** of your encrypted secrets and age keys

## Additional Resources

- [Homepage Documentation](https://gethomepage.dev/)
- [SOPS Documentation](https://github.com/getsops/sops)
- [Helm Secrets Plugin](https://github.com/jkroepke/helm-secrets)
