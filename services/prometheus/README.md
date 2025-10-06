# Prometheus Monitoring Stack

This directory contains a complete Kubernetes deployment for Prometheus monitoring stack including Prometheus server and AlertManager.

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Prometheus Stack                         │
├─────────────────────────┬───────────────────────────────────┤
│      Prometheus         │         AlertManager              │
│   ┌─────────────────┐   │   ┌─────────────────────────────┐ │
│   │  Data Storage   │   │   │    Alert Rules              │ │
│   │  - 30d retention│   │   │    - Routing                │ │
│   │  - 20GB storage │   │   │    - Notifications          │ │
│   └─────────────────┘   │   │    - Webhooks               │ │
│   ┌─────────────────┐   │   └─────────────────────────────┘ │
│   │  Scrape Targets │   │   ┌─────────────────────────────┐ │
│   │  - K8s API      │   │   │    Storage                  │ │
│   │  - Nodes        │   │   │    - 5GB PVC                │ │
│   │  - Pods         │   │   │    - Alert History          │ │
│   │  - Services     │   │   └─────────────────────────────┘ │
│   │  - cAdvisor     │   │                                   │
│   └─────────────────┘   │                                   │
└─────────────────────────┴───────────────────────────────────┘
         │                              │
         │ NodePort 30090               │ NodePort 30093
         ▼                              ▼
┌─────────────────┐              ┌─────────────────┐
│  Prometheus UI  │              │ AlertManager UI │
│  Metrics Query  │              │ Alert Management│
│  Dashboards     │              │ Silencing       │
└─────────────────┘              └─────────────────┘
```

## 🚀 Quick Start

### 1. Deploy Prometheus Stack

```bash
# Deploy all components
kubectl apply -f prometheus-deployment.yaml

# Check deployment status
kubectl get pods -n prometheus

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n prometheus --timeout=300s
```

### 2. Access Interfaces

**Prometheus Web UI:**
- NodePort: `http://<node-ip>:30090`
- Port Forward: `kubectl port-forward svc/prometheus -n prometheus 9090:9090`
- Internal: `http://prometheus.prometheus.svc.cluster.local:9090`

**AlertManager Web UI:**
- NodePort: `http://<node-ip>:30093`
- Port Forward: `kubectl port-forward svc/alertmanager -n prometheus 9093:9093`
- Internal: `http://alertmanager.prometheus.svc.cluster.local:9093`

### 3. Verify Monitoring

```bash
# Check if targets are being scraped
curl -s http://<node-ip>:30090/api/v1/targets | jq '.data.activeTargets[] | select(.health == "up") | .labels.job'

# Query basic metrics
curl -s "http://<node-ip>:30090/api/v1/query?query=up" | jq '.data.result'
```

## 📋 Components

### Prometheus Server
- **Version**: 2.45.0
- **Storage**: 20GB PVC with 30-day retention
- **Resources**: 512Mi-2Gi memory, 200m-1000m CPU
- **Features**: 
  - Kubernetes service discovery
  - Alert rule evaluation
  - TSDB storage engine
  - Web API and UI

### AlertManager
- **Version**: 0.25.0
- **Storage**: 5GB PVC for alert state
- **Resources**: 128Mi-512Mi memory, 100m-500m CPU
- **Features**:
  - Alert routing and grouping
  - Notification channels
  - Silencing and inhibition
  - Clustering support

## 🎯 Monitoring Targets

### Automatic Discovery
- **Kubernetes API Server**: Cluster-level metrics
- **Kubernetes Nodes**: Node resource metrics
- **Kubernetes Pods**: Application metrics (with annotations)
- **Kubernetes Services**: Service-level metrics (with annotations)
- **cAdvisor**: Container resource metrics

### Static Targets
- **Prometheus**: Self-monitoring metrics
- **ArgoCD**: GitOps platform metrics (if deployed)
- **Gitea**: Git service metrics (if deployed)

### Service Discovery Configuration

For pods to be scraped, add these annotations:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

For services to be scraped, add these annotations:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
  prometheus.io/scheme: "http"
```

## 🚨 Alert Rules

### Built-in Alerts
- **KubernetesPodCrashLooping**: Pods restarting frequently
- **KubernetesNodeReady**: Nodes not in ready state
- **KubernetesPodNotReady**: Pods stuck in pending/unknown state
- **KubernetesHighCPUUsage**: Pods using >80% CPU
- **KubernetesHighMemoryUsage**: Pods using >80% memory

### Custom Alert Rules

Add custom rules to the ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: prometheus
data:
  custom-rules.yml: |
    groups:
    - name: custom-alerts
      rules:
      - alert: HighDiskUsage
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage detected"
          description: "Disk usage is above 90% on {{ $labels.instance }}"
```

Then update the deployment to mount the new rules.

## 🔧 Configuration

### Prometheus Configuration

The main configuration is stored in the `prometheus-config` ConfigMap:

- **Global Settings**: Scrape interval, evaluation interval, external labels
- **Rule Files**: Alert rule definitions
- **Alerting**: AlertManager integration
- **Scrape Configs**: Target discovery and scraping configuration

### AlertManager Configuration

AlertManager configuration includes:
- **Global Settings**: SMTP configuration for email alerts
- **Routing**: How alerts are grouped and routed
- **Receivers**: Where to send notifications (webhook, email, Slack, etc.)
- **Inhibition**: Rules to suppress alerts based on other alerts

### Storage Configuration

- **Prometheus**: 20GB PVC with 30-day retention and 15GB size limit
- **AlertManager**: 5GB PVC for alert state persistence
- **Retention**: Configurable via `--storage.tsdb.retention.time` and `--storage.tsdb.retention.size`

## 📊 Querying and Analysis

### Basic PromQL Queries

```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by pod
container_memory_working_set_bytes

# Pod restart count
increase(kube_pod_container_status_restarts_total[1h])

# Node CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Available disk space
node_filesystem_avail_bytes{fstype!="tmpfs"}
```

### HTTP API Examples

```bash
# Query current CPU usage
curl "http://localhost:9090/api/v1/query?query=rate(container_cpu_usage_seconds_total[5m])"

# Query range data
curl "http://localhost:9090/api/v1/query_range?query=up&start=2023-01-01T00:00:00Z&end=2023-01-01T01:00:00Z&step=15s"

# Get all metrics
curl "http://localhost:9090/api/v1/label/__name__/values"

# Get targets
curl "http://localhost:9090/api/v1/targets"
```

## 🔒 Security

### RBAC Configuration
- Service accounts with minimal required permissions
- ClusterRole for reading Kubernetes resources
- No write permissions to cluster resources

### Network Security
- Internal communication over ClusterIP services
- External access only via NodePort (configurable)
- No default Ingress configuration

### Data Security
- Metrics data stored in PersistentVolumes
- No sensitive data in metrics (labels should not contain secrets)
- Regular backup of configuration and data recommended

## 🚀 Integrations

### Grafana Integration

Connect Grafana to Prometheus:
```yaml
datasources:
- name: Prometheus
  type: prometheus
  url: http://prometheus.prometheus.svc.cluster.local:9090
  access: proxy
```

### Application Integration

Add metrics endpoint to your applications:
```yaml
# Deployment example
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: my-app:latest
        ports:
        - containerPort: 8080
          name: metrics
```

### Alerting Integration

#### Slack Integration
```yaml
receivers:
- name: 'slack-alerts'
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#alerts'
    title: 'Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

#### PagerDuty Integration
```yaml
receivers:
- name: 'pagerduty-critical'
  pagerduty_configs:
  - service_key: 'YOUR_SERVICE_KEY'
    description: '{{ .GroupLabels.alertname }}: {{ .GroupLabels.instance }}'
```

## 📈 Monitoring Best Practices

### Metric Naming
- Use descriptive metric names following Prometheus conventions
- Include units in metric names (e.g., `_seconds`, `_bytes`)
- Use consistent label naming across metrics

### Label Management
- Keep cardinality low (avoid high-cardinality labels like UUIDs)
- Use meaningful label names and values
- Be consistent with label naming across services

### Alert Design
- Create actionable alerts that require human intervention
- Use appropriate severity levels
- Include runbook links in alert annotations
- Test alert rules before deploying

### Resource Planning
- Monitor Prometheus memory usage and adjust limits as needed
- Plan storage based on retention requirements and cardinality
- Consider federation for large-scale deployments

## 🔍 Troubleshooting

### Common Issues

#### Prometheus Not Scraping Targets
```bash
# Check service discovery
curl http://localhost:9090/api/v1/targets

# Check Prometheus logs
kubectl logs deployment/prometheus -n prometheus

# Verify network connectivity
kubectl exec -it deployment/prometheus -n prometheus -- wget -O- http://target:port/metrics
```

#### High Memory Usage
```bash
# Check memory metrics
curl "http://localhost:9090/api/v1/query?query=prometheus_tsdb_symbol_table_size_bytes"

# Review cardinality
curl "http://localhost:9090/api/v1/label/__name__/values" | jq '. | length'

# Adjust retention or increase resources
```

#### AlertManager Not Receiving Alerts
```bash
# Check AlertManager targets in Prometheus
curl http://localhost:9090/api/v1/alertmanagers

# Check AlertManager logs
kubectl logs deployment/alertmanager -n prometheus

# Verify alert rules are firing
curl http://localhost:9090/api/v1/alerts
```

### Debugging Commands

```bash
# Get all Prometheus configuration
kubectl get configmap prometheus-config -n prometheus -o yaml

# Check PVC status
kubectl get pvc -n prometheus

# Restart Prometheus (reload config)
curl -X POST http://localhost:9090/-/reload

# Check AlertManager configuration
curl http://localhost:9093/api/v1/status/config
```

## 📚 Useful Queries

### Cluster Health
```promql
# Cluster nodes ready
kube_node_status_condition{condition="Ready",status="true"}

# Pod availability
kube_deployment_status_replicas_available / kube_deployment_spec_replicas

# Persistent volume usage
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100
```

### Resource Usage
```promql
# Top CPU consuming pods
topk(10, rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m]))

# Top memory consuming pods
topk(10, container_memory_working_set_bytes{container!="POD",container!=""})

# Network I/O by pod
rate(container_network_receive_bytes_total[5m])
rate(container_network_transmit_bytes_total[5m])
```

### Application Metrics
```promql
# HTTP request rate
rate(http_requests_total[5m])

# HTTP request duration
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])
```

## 🚀 Advanced Configuration

### Federation Setup

For multi-cluster monitoring:
```yaml
scrape_configs:
- job_name: 'federate'
  scrape_interval: 15s
  honor_labels: true
  metrics_path: '/federate'
  params:
    'match[]':
      - '{job=~"kubernetes-.*"}'
      - '{__name__=~"job:.*"}'
  static_configs:
  - targets:
    - 'remote-prometheus:9090'
```

### Recording Rules

For complex calculations:
```yaml
groups:
- name: instance_rules
  interval: 30s
  rules:
  - record: instance:node_cpu_utilisation:rate5m
    expr: 1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))
  
  - record: instance:node_memory_utilisation:ratio
    expr: 1 - ((node_memory_MemAvailable_bytes or (node_memory_Buffers_bytes + node_memory_Cached_bytes + node_memory_MemFree_bytes)) / node_memory_MemTotal_bytes)
```

### High Availability

For HA deployment, use multiple replicas with shared storage or external storage:
```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
```

## 🗂️ File Structure

```
services/prometheus/
├── prometheus-deployment.yaml    # Complete K8s deployment
├── README.md                    # This documentation
└── deploy.sh                   # Deployment automation script
```

## 🔗 References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Kubernetes Service Discovery](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config)
- [Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)