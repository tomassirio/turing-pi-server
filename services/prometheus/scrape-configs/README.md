# Prometheus Scrape Configurations

This directory contains **organized scrape configurations** for documentation and easy management.

## Structure

```
scrape-configs/
├── core/
│   └── scrape-config.yml           # Prometheus self-monitoring, kube-state-metrics
├── kubernetes/
│   └── discovery.yml               # Kubernetes auto-discovery configs
└── wanderer/
    ├── production.yml              # Wanderer production services
    └── development.yml             # Wanderer development services
```

## Important: How This Works

⚠️ **These files are for ORGANIZATION and REFERENCE only.**

The actual scrape configurations are **embedded in `templates/configmap.yaml`** because Prometheus requires all scrape configs to be in a single `scrape_configs` section.

**This folder structure serves to:**
- ✅ Keep scrape configs organized by project/category
- ✅ Make it easy to find and update specific configs
- ✅ Provide clear documentation of what's being monitored
- ✅ Enable easy copy-paste when adding new services

## How to Update Configurations

### Adding a Service to Wanderer

1. **Edit the reference file:** `wanderer/production.yml` or `wanderer/development.yml`
   - Add your new service configuration

2. **Copy the new job to:** `templates/configmap.yaml`
   - Find the `# Wanderer - Production` or `# Wanderer - Development` section
   - Paste your new job configuration

3. **Deploy:**
   ```bash
   helm upgrade prometheus ./services/prometheus \
     --namespace <prometheus-namespace> \
     --reuse-values
   ```

### Example: Adding wanderer-notifications

1. **Add to `wanderer/production.yml`:**
```yaml
- job_name: 'wanderer-notifications-prod'
  metrics_path: '/actuator/prometheus'
  scrape_interval: 15s
  static_configs:
    - targets: ['wanderer-notifications.wanderer.svc.cluster.local:8084']
      labels:
        project: 'wanderer'
        application: 'wanderer-notifications'
        environment: 'production'
        namespace: 'wanderer'
        component: 'notifications'
```

2. **Copy to `templates/configmap.yaml`** under the `# Wanderer - Production` section

3. **Repeat for development** in `wanderer/development.yml` and configmap.yaml

## File Purposes

### `core/scrape-config.yml`
Reference for:
- Prometheus self-monitoring
- Kube-state-metrics

### `kubernetes/discovery.yml`
Reference for:
- Kubernetes API server metrics
- Kubernetes node metrics (kubelet)
- Kubernetes node metrics (cadvisor)
- Pod auto-discovery (prometheus.io/scrape annotation)
- Service auto-discovery (prometheus.io/scrape annotation)

### `wanderer/production.yml`
Reference for all Wanderer production services:
- wanderer-auth
- wanderer-command
- wanderer-query
- (future services...)

### `wanderer/development.yml`
Reference for all Wanderer development services:
- wanderer-auth-dev
- wanderer-command-dev
- wanderer-query-dev
- (future services...)

## Adding New Environments

To add staging for Wanderer:

1. Create: `wanderer/staging.yml`
2. Add your scrape configs
3. Copy to `templates/configmap.yaml` under a new `# Wanderer - Staging` section
4. Deploy

## Adding New Projects

To add a new project:

1. Create folder: `mkdir scrape-configs/myapp`
2. Create files: `myapp/production.yml`, `myapp/development.yml`
3. Add your scrape configs
4. Copy to `templates/configmap.yaml` under new `# MyApp - *` sections
5. Deploy

## Best Practices

✅ **Always update both:** Update the reference file AND configmap.yaml  
✅ **Keep them in sync:** Reference files should match what's in configmap.yaml  
✅ **Use reference files as source of truth:** Copy from reference files to configmap.yaml  
✅ **Document changes:** Add comments in reference files  
✅ **Test before deploy:** Use `helm template` to verify syntax  

## Why This Structure?

While we'd prefer to split configs into separate Helm templates/ConfigMaps, Prometheus requires all scrape configs to be in a single YAML structure. This folder organization provides:

- **Documentation**: Clear reference of what's being monitored
- **Organization**: Easy to find specific project configs
- **Maintainability**: Update reference file, copy to main config
- **Clarity**: Separate files are easier to review than one big file
- **Version Control**: Clear git diffs per project

## Quick Reference

| What | Where (Reference) | Where (Actual) |
|------|-------------------|----------------|
| Core monitoring | `core/scrape-config.yml` | `templates/configmap.yaml` |
| K8s discovery | `kubernetes/discovery.yml` | `templates/configmap.yaml` |
| Wanderer prod | `wanderer/production.yml` | `templates/configmap.yaml` |
| Wanderer dev | `wanderer/development.yml` | `templates/configmap.yaml` |

## Deployment

After updating `templates/configmap.yaml`:

```bash
cd /Users/tomassirio/Workspace/turing-pi-server

helm upgrade prometheus ./services/prometheus \
  --namespace <prometheus-namespace> \
  --reuse-values
```

Prometheus will reload the configuration automatically.
