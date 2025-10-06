# Gitea Kubernetes Deployment

This directory contains Kubernetes deployment descriptors for Gitea, a lightweight Git service written in Go.

## Overview

The deployment includes:
- **Gitea**: Main Git service with web UI
- **PostgreSQL**: Database backend for Gitea
- **Persistent Storage**: Data persistence for repositories and database
- **Services**: ClusterIP and NodePort for external access
- **ConfigMap**: Gitea configuration
- **Secrets**: Credentials and security keys

## Architecture

```
┌─────────────────┐
│    NodePort     │
│   Port 30300    │ (HTTP)
│   Port 30022    │ (SSH)
└─────────┬───────┘
          │
┌─────────▼───────┐
│      Gitea      │
│   Port 3000     │
│   Port 22 (SSH) │
└─────────┬───────┘
          │
┌─────────▼───────┐
│   PostgreSQL    │
│   Port 5432     │
└─────────────────┘
```

## Prerequisites

- Kubernetes cluster (1.19+)
- kubectl configured
- StorageClass named "standard" available
- Optional: Ingress controller (nginx) for domain-based access

## Quick Deploy

```bash
# Deploy all components
kubectl apply -f gitea-deployment.yaml

# Check deployment status
kubectl get pods -n gitea
kubectl get services -n gitea
```

## Configuration

### Default Credentials
- **Admin Username**: `admin`
- **Admin Password**: `admin123`
- **Database**: PostgreSQL with user `gitea` and password `giteapass`

⚠️ **Security Warning**: Change default credentials in production!

### Storage
- **Gitea Data**: 10Gi PVC for repositories and application data
- **PostgreSQL**: 5Gi PVC for database storage

### Access Methods

1. **NodePort** (direct node access):
   ```bash
   # Get node IP
   kubectl get nodes -o wide
   
   # Access Gitea
   # Web UI: http://<NODE_IP>:30300
   # SSH: <NODE_IP>:30022
   ```

2. **Port Forward** (local development):
   ```bash
   kubectl port-forward service/gitea 3000:3000 -n gitea
   # Access via http://localhost:3000
   ```

3. **Cluster Internal**:
   ```bash
   # Internal service access
   # HTTP: gitea.gitea.svc.cluster.local:3000
   # SSH: gitea.gitea.svc.cluster.local:22
   ```

## Advanced Configuration

### Custom Configuration

Edit the ConfigMap to customize Gitea settings:

```bash
kubectl edit configmap gitea-config -n gitea
```

Key configuration sections:
- **[server]**: Domain, ports, SSL settings
- **[database]**: Database connection
- **[repository]**: Git repository settings
- **[service]**: User registration, email settings
- **[security]**: Security and authentication

### Scaling

The deployment is configured for single-replica operation. For high availability:

1. Scale PostgreSQL with replication
2. Use shared storage (ReadWriteMany)
3. Configure Gitea clustering

### Security Hardening

1. **Change default passwords**:
   ```bash
   kubectl create secret generic gitea-secret \
     --from-literal=admin-username=youradmin \
     --from-literal=admin-password=yourpassword \
     --from-literal=db-password=yourdbpassword \
     --from-literal=jwt-secret=$(openssl rand -base64 32) \
     -n gitea --dry-run=client -o yaml | kubectl apply -f -
   ```

2. **Enable TLS**:
   - Configure ingress with TLS certificates
   - Update Gitea config for HTTPS

3. **Network Policies**:
   - Restrict inter-pod communication
   - Limit external access

## Backup and Recovery

### Backup Repositories
```bash
# Backup Gitea data
kubectl exec -it deployment/gitea -n gitea -- tar -czf /tmp/gitea-backup.tar.gz /data/git/repositories

# Copy backup locally
kubectl cp gitea/deployment/gitea:/tmp/gitea-backup.tar.gz ./gitea-backup.tar.gz
```

### Backup Database
```bash
# Database backup
kubectl exec -it deployment/gitea-postgres -n gitea -- pg_dump -U gitea gitea > gitea-db-backup.sql
```

### Restore
```bash
# Restore repositories
kubectl cp ./gitea-backup.tar.gz gitea/deployment/gitea:/tmp/
kubectl exec -it deployment/gitea -n gitea -- tar -xzf /tmp/gitea-backup.tar.gz -C /

# Restore database
kubectl exec -i deployment/gitea-postgres -n gitea -- psql -U gitea gitea < gitea-db-backup.sql
```

## Monitoring

### Health Checks
```bash
# Check pod status
kubectl get pods -n gitea

# Check logs
kubectl logs -f deployment/gitea -n gitea
kubectl logs -f deployment/gitea-postgres -n gitea

# Health endpoint
kubectl port-forward service/gitea 3000:3000 -n gitea &
curl http://localhost:3000/api/healthz
```

### Metrics
Gitea exposes Prometheus metrics at `/metrics` endpoint when enabled in configuration.

## Troubleshooting

### Common Issues

1. **Pod stuck in Pending**:
   - Check PVC binding: `kubectl get pvc -n gitea`
   - Verify StorageClass: `kubectl get storageclass`

2. **Database connection errors**:
   - Check PostgreSQL logs: `kubectl logs deployment/gitea-postgres -n gitea`
   - Verify service: `kubectl get service gitea-postgres -n gitea`

3. **Permission errors**:
   - Check init container logs
   - Verify fsGroup and runAsUser settings

4. **SSH access issues**:
   - For SSH access via LoadBalancer, use port 2222
   - Configure SSH keys in Gitea web UI

### Debug Commands
```bash
# Shell into Gitea container
kubectl exec -it deployment/gitea -n gitea -- /bin/bash

# Check Gitea configuration
kubectl exec -it deployment/gitea -n gitea -- cat /data/gitea/conf/app.ini

# Test database connection
kubectl exec -it deployment/gitea-postgres -n gitea -- psql -U gitea -d gitea -c "SELECT version();"
```

## Cleanup

```bash
# Remove all resources
kubectl delete -f gitea-deployment.yaml

# Remove PVCs (if desired)
kubectl delete pvc gitea-data-pvc gitea-postgres-pvc -n gitea

# Remove namespace
kubectl delete namespace gitea
```

## Integration with Other Services

### With ArgoCD
- Add Gitea repositories as ArgoCD sources
- Use SSH keys or tokens for authentication

### With CI/CD
- Configure webhooks for automated builds
- Use Gitea API for repository management

### With LDAP/OAuth
- Configure external authentication in app.ini
- Support for GitHub, GitLab, Google OAuth

## Resources

- [Gitea Documentation](https://docs.gitea.io/)
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [PostgreSQL on Kubernetes](https://postgres-operator.readthedocs.io/)