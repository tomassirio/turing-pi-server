# Grafana Dashboard PromQL Queries

This document contains recommended PromQL queries for monitoring your Turing Pi Kubernetes cluster.

## ⚠️ Important Note: Duplicate Metrics

Your kube-state-metrics is being scraped by two different Prometheus jobs:
- `job="kubernetes-services"` (scraping the kube-state-metrics service)
- `job="kubernetes-pods"` (scraping the kube-state-metrics pod directly)

This causes metrics like `kube_node_info` to return **duplicate results** (e.g., 10 instead of 5 nodes).

**Solution**: Always filter by `job="kubernetes-services"` or use `count by (node)` to deduplicate.

Example:
```promql
# ❌ Wrong - returns 10 (duplicates)
count(kube_node_info)

# ✅ Correct - returns 5 (unique nodes)
count by (node) (kube_node_info)

# ✅ Also correct - returns 5
count(kube_node_info{job="kubernetes-services"})
```

## 📊 Dashboard Structure

### 1. Cluster Overview Panel

#### Total Nodes
```promql
count by (node) (kube_node_info)
```
or:
```promql
count(kube_node_info{job="kubernetes-services"})
```

#### Total Namespaces
```promql
count(kube_namespace_created)
```

#### Total Pods Running
```promql
sum(kube_pod_status_phase{phase="Running"})
```

#### Total Deployments
```promql
count(kube_deployment_created)
```

---

### 2. Node Health & Capacity

#### Node Status (Ready/NotReady)
```promql
kube_node_status_condition{condition="Ready", status="true", job="kubernetes-services"}
```
or count ready nodes:
```promql
count(kube_node_status_condition{condition="Ready", status="true", job="kubernetes-services"})
```

#### CPU Capacity by Node
```promql
kube_node_status_capacity{resource="cpu", job="kubernetes-services"}
```

#### Memory Capacity by Node (GB)
```promql
kube_node_status_capacity{resource="memory", job="kubernetes-services"} / 1024 / 1024 / 1024
```

#### CPU Allocatable by Node
```promql
kube_node_status_allocatable{resource="cpu", job="kubernetes-services"}
```

#### Memory Allocatable by Node (GB)
```promql
kube_node_status_allocatable{resource="memory", job="kubernetes-services"} / 1024 / 1024 / 1024
```

#### Storage Capacity by Node (GB)
```promql
kube_node_status_capacity{resource="ephemeral_storage", job="kubernetes-services"} / 1024 / 1024 / 1024
```

---

### 3. Pod Health & Status

#### Pods by Phase
```promql
sum by (phase) (kube_pod_status_phase)
```

#### Pods Not Running (Problems)
```promql
count(kube_pod_status_phase{phase!="Running",phase!="Succeeded"})
```

#### Container Restarts (Last Hour)
```promql
sum(rate(kube_pod_container_status_restarts_total[1h])) by (namespace, pod, container)
```

#### Pods in CrashLoopBackOff
```promql
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}
```

#### Pods in ImagePullBackOff
```promql
kube_pod_container_status_waiting_reason{reason="ImagePullBackOff"}
```

#### Container Ready Status
```promql
sum by (namespace, pod) (kube_pod_container_status_ready)
```

---

### 4. Deployment Status

#### Deployment Replicas - Desired vs Available
```promql
# Desired
kube_deployment_spec_replicas

# Available
kube_deployment_status_replicas_available

# Combined query for comparison
kube_deployment_spec_replicas - kube_deployment_status_replicas_available
```

#### Deployments Not Fully Available
```promql
kube_deployment_spec_replicas - kube_deployment_status_replicas_available > 0
```

#### Deployment Rollout Status
```promql
kube_deployment_status_condition{condition="Progressing", status="true"}
```

#### Unavailable Replicas by Deployment
```promql
kube_deployment_status_replicas_unavailable > 0
```

---

### 5. Resource Usage (Per Service)

#### CPU Requests by Namespace
```promql
sum by (namespace) (kube_pod_container_resource_requests{resource="cpu"})
```

#### Memory Requests by Namespace (GB)
```promql
sum by (namespace) (kube_pod_container_resource_requests{resource="memory"}) / 1024 / 1024 / 1024
```

#### CPU Limits by Namespace
```promql
sum by (namespace) (kube_pod_container_resource_limits{resource="cpu"})
```

#### Memory Limits by Namespace (GB)
```promql
sum by (namespace) (kube_pod_container_resource_limits{resource="memory"}) / 1024 / 1024 / 1024
```

#### Pods by Namespace
```promql
count by (namespace) (kube_pod_info)
```

---

### 6. Storage & Persistence

#### PVC Status by Phase
```promql
sum by (phase) (kube_persistentvolumeclaim_status_phase)
```

#### PVC Storage Requests (GB)
```promql
kube_persistentvolumeclaim_resource_requests_storage_bytes / 1024 / 1024 / 1024
```

#### PV Capacity by StorageClass (GB)
```promql
sum by (storageclass) (kube_persistentvolume_capacity_bytes) / 1024 / 1024 / 1024
```

#### PVC in Pending State
```promql
kube_persistentvolumeclaim_status_phase{phase="Pending"}
```

#### Total Storage Provisioned (GB)
```promql
sum(kube_persistentvolume_capacity_bytes) / 1024 / 1024 / 1024
```

---

### 7. Service & Networking

#### Total Services
```promql
count(kube_service_info)
```

#### Services by Type
```promql
sum by (type) (kube_service_spec_type)
```

#### LoadBalancer Services
```promql
count(kube_service_spec_type{type="LoadBalancer"})
```

#### Ingress Resources
```promql
count(kube_ingress_info)
```

#### Endpoint Addresses Available
```promql
sum by (namespace, endpoint) (kube_endpoint_address_available)
```

#### Endpoint Addresses Not Ready
```promql
sum by (namespace, endpoint) (kube_endpoint_address_not_ready)
```

---

### 8. StatefulSets (For Your Media Services)

#### StatefulSet Replicas - Ready vs Desired
```promql
# Desired
kube_statefulset_replicas

# Ready
kube_statefulset_status_replicas_ready

# Comparison
kube_statefulset_replicas - kube_statefulset_status_replicas_ready
```

#### StatefulSets Not Ready
```promql
kube_statefulset_replicas - kube_statefulset_status_replicas_ready > 0
```

#### StatefulSet Current Replicas
```promql
kube_statefulset_status_replicas_current
```

---

### 9. Jobs & CronJobs

#### Active Jobs
```promql
sum(kube_job_status_active)
```

#### Failed Jobs
```promql
sum(kube_job_status_failed)
```

#### Job Success Rate
```promql
sum(kube_job_status_succeeded) / (sum(kube_job_status_succeeded) + sum(kube_job_status_failed))
```

#### CronJobs Next Schedule Time
```promql
kube_cronjob_next_schedule_time
```

#### CronJob Last Success Time
```promql
kube_cronjob_status_last_successful_time
```

#### Suspended CronJobs
```promql
kube_cronjob_spec_suspend == 1
```

#### CronJobs with Active Jobs
```promql
kube_cronjob_status_active > 0
```

---

### 10. DaemonSets

#### DaemonSet Desired vs Available
```promql
# Desired
kube_daemonset_status_desired_number_scheduled

# Available
kube_daemonset_status_number_available

# Comparison
kube_daemonset_status_desired_number_scheduled - kube_daemonset_status_number_available
```

#### DaemonSet Misscheduled Pods
```promql
kube_daemonset_status_number_misscheduled > 0
```

---

### 11. Application-Specific Monitoring

#### Media Services Pod Status (Sonarr, Radarr, etc.)
```promql
kube_pod_status_phase{namespace=~".*arr|seerr|jellyfin"}
```

#### Torrent Client Status (qBittorrent)
```promql
kube_pod_status_phase{namespace="qbittorrent", phase="Running"}
```

#### DNS Services Health (Technitium, Pi-hole)
```promql
kube_pod_status_phase{namespace=~"technitium|pi-hole", phase="Running"}
```

#### Container Restarts for Media Services (Last 24h)
```promql
increase(kube_pod_container_status_restarts_total{namespace=~".*arr|seerr|jellyfin|qbittorrent"}[24h])
```

---

### 12. Secrets & ConfigMaps

#### Total Secrets
```promql
count(kube_secret_info)
```

#### Total ConfigMaps
```promql
count(kube_configmap_info)
```

#### Secrets by Namespace
```promql
count by (namespace) (kube_secret_info)
```

---

### 13. Alert Conditions

#### Pods in Failed State
```promql
kube_pod_status_phase{phase="Failed"} > 0
```

#### Pods in Unknown State
```promql
kube_pod_status_phase{phase="Unknown"} > 0
```

#### High Container Restart Rate
```promql
rate(kube_pod_container_status_restarts_total[5m]) > 0.1
```

#### Deployment Replica Mismatch
```promql
(kube_deployment_spec_replicas - kube_deployment_status_replicas_available) > 0
```

#### PVC Pending for Too Long
```promql
kube_persistentvolumeclaim_status_phase{phase="Pending"} * on(persistentvolumeclaim, namespace) group_left() (time() - kube_persistentvolumeclaim_created) > 300
```

---

### 14. Capacity Planning

#### Total CPU Requests vs Allocatable
```promql
# Requests
sum(kube_pod_container_resource_requests{resource="cpu"})

# Allocatable
sum(kube_node_status_allocatable{resource="cpu", job="kubernetes-services"})

# Usage percentage
sum(kube_pod_container_resource_requests{resource="cpu"}) / sum(kube_node_status_allocatable{resource="cpu", job="kubernetes-services"}) * 100
```

#### Total Memory Requests vs Allocatable (%)
```promql
sum(kube_pod_container_resource_requests{resource="memory"}) / sum(kube_node_status_allocatable{resource="memory", job="kubernetes-services"}) * 100
```

#### CPU Overcommit Ratio
```promql
sum(kube_pod_container_resource_limits{resource="cpu"}) / sum(kube_node_status_allocatable{resource="cpu", job="kubernetes-services"})
```

#### Memory Overcommit Ratio
```promql
sum(kube_pod_container_resource_limits{resource="memory"}) / sum(kube_node_status_allocatable{resource="memory", job="kubernetes-services"})
```

---

### 15. Time-Based Metrics

#### Pod Age (Days)
```promql
(time() - kube_pod_start_time) / 86400
```

#### Deployment Age (Days)
```promql
(time() - kube_deployment_created) / 86400
```

#### Time Since Last Container Restart
```promql
time() - kube_pod_container_state_started
```

---

## 📈 Recommended Dashboard Layout

### Row 1: Cluster Overview (Single Stats)
- Total Nodes (use `count by (node)` to avoid duplicates)
- Total Namespaces
- Running Pods
- Total Deployments

### Row 2: Resource Capacity (Gauge/Bar Charts)
- CPU Usage % (filter by `job="kubernetes-services"`)
- Memory Usage %
- Storage Usage %

### Row 3: Pod Health (Time Series)
- Pods by Phase (Stacked Graph)
- Container Restarts (Line Graph)

### Row 4: Service Health (Tables/Heatmaps)
- Deployment Status Table
- StatefulSet Status Table
- Media Services Uptime

### Row 5: Storage (Pie Charts/Tables)
- PVC Status
- Storage by Namespace

### Row 6: Alerts & Issues (Alert List)
- Failed Pods
- High Restart Rate Containers
- Deployment Mismatches

### Row 7: Application-Specific (Mixed)
- Media Service Status
- DNS Service Status
- Backup Job Status

---

## 🎨 Visualization Tips

### Use These Visualization Types:

1. **Stat Panels**: Single value metrics (totals, counts)
2. **Time Series**: Trends over time (restarts, phase changes)
3. **Gauge**: Percentage-based metrics (CPU/Memory usage)
4. **Bar Gauge**: Comparative metrics (resources per namespace)
5. **Table**: Detailed lists (deployment status, pod details)
6. **Heatmap**: Container restarts over time
7. **Pie Chart**: Distribution (services by type, pods by phase)
8. **Alert List**: Current alerts and warnings

### Color Coding:
- 🟢 Green: Healthy (0 issues)
- 🟡 Yellow: Warning (1-3 issues)
- 🔴 Red: Critical (>3 issues or any failed state)

---

## 🔔 Recommended Alerts

Configure these alerts in your Grafana or Prometheus setup:

1. **Pod not running**: `kube_pod_status_phase{phase!="Running",phase!="Succeeded"} > 0`
2. **High restart rate**: `rate(kube_pod_container_status_restarts_total[15m]) > 0.1`
3. **Deployment unavailable**: `kube_deployment_status_replicas_unavailable > 0`
4. **PVC pending**: `kube_persistentvolumeclaim_status_phase{phase="Pending"} > 0`
5. **Node not ready**: `kube_node_status_condition{condition="Ready",status="false",job="kubernetes-services"} > 0`

---

## 📝 Notes

- All queries are optimized for kube-state-metrics
- **Always filter by `job="kubernetes-services"`** or use `count by (node)` for node metrics to avoid duplicates
- Time ranges can be adjusted using Grafana's time picker
- Use `namespace=~"regex"` to filter specific services
- Consider creating separate dashboards for:
  - **Cluster Overview**: General health
  - **Media Stack**: Sonarr, Radarr, Jellyfin, etc.
  - **Infrastructure**: DNS, networking, storage
  - **Jobs & Automation**: CronJobs, cleanup tasks

---

## 🚀 Quick Start

1. Import a base Kubernetes dashboard (e.g., Dashboard ID: 15661)
2. Customize with queries from this document
3. Add variables for dynamic filtering:
   - `$namespace`: Namespace selector
   - `$pod`: Pod selector
   - `$deployment`: Deployment selector
4. Remember to filter node metrics by `job="kubernetes-services"` to show correct counts

---

## 🔧 Troubleshooting Duplicate Metrics

If you see duplicate metrics in your queries:

**Problem**: `count(kube_node_info)` returns 10 instead of 5 nodes

**Root Cause**: Prometheus is scraping kube-state-metrics from both:
- The service endpoint (`job="kubernetes-services"`)
- The pod directly (`job="kubernetes-pods"`)

**Solutions**:
1. Filter by job: `count(kube_node_info{job="kubernetes-services"})`
2. Deduplicate: `count by (node) (kube_node_info)`
3. Update Prometheus scrape config to only scrape one endpoint

**Affected Metrics**:
- `kube_node_info`
- `kube_node_status_condition`
- `kube_node_status_capacity`
- `kube_node_status_allocatable`

All node-related queries in this document have been updated to handle this correctly.

