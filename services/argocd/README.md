# ArgoCD Kubernetes Deployment

This directory contains Kubernetes deployment descriptors for ArgoCD, a declarative GitOps continuous delivery tool for Kubernetes.

## Overview

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It follows the GitOps pattern of using Git repositories as the source of truth for defining the desired application state.

### Components Included

- **ArgoCD Server**: Web UI and API server
- **ArgoCD Application Controller**: Monitors applications and manages their lifecycle
- **ArgoCD Repo Server**: Manages Git repositories and generates manifests
- **ArgoCD Dex Server**: Identity and authentication provider
- **Redis**: Cache and message broker
- **RBAC**: Role-based access control configuration
- **NodePort Service**: External access via node ports

## Architecture

```
┌─────────────────┐
│    NodePort     │
│   Port 30080    │ (HTTP)
│   Port 30443    │ (gRPC)
└─────────┬───────┘
          │
┌─────────▼───────┐
│  ArgoCD Server  │
│   Port 8080     │
└─────────┬───────┘
          │
├─────────┼────────────────────┐
│         │                    │
▼         ▼                    ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Application │  │ Repo Server │  │ Dex Server  │
│ Controller  │  │ Port 8081   │  │ Port 5556   │
└─────────────┘  └─────────────┘  └─────────────┘
          │
          ▼
    ┌─────────┐
    │  Redis  │
    │Port 6379│
    └─────────┘
```

## Prerequisites

- Kubernetes cluster (1.20+)
- kubectl configured
- Cluster admin permissions
- 2GB+ available memory
- 2 CPU cores recommended

## Quick Deploy

```bash
# Deploy ArgoCD
kubectl apply -f argocd-deployment.yaml

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-secret -o jsonpath='{.data.admin\.password}' | base64 -d
```

## Configuration

### Default Credentials
- **Username**: `admin`
- **Password**: Retrieve with:
  ```bash
  kubectl -n argocd get secret argocd-secret -o jsonpath='{.data.admin\.password}' | base64 -d
  ```
- **Default Password**: `argocd123` (change immediately!)

### Access Methods

#### 1. NodePort Access
```bash
# Get node IP
kubectl get nodes -o wide

# Access ArgoCD UI
# Web UI: http://<NODE_IP>:30080
# CLI: <NODE_IP>:30443 (gRPC)
```

#### 2. Port Forward (Local Development)
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Access via http://localhost:8080
```

#### 3. kubectl Proxy
```bash
kubectl proxy

# Access via http://localhost:8001/api/v1/namespaces/argocd/services/argocd-server:http/proxy/
```

### Security Configuration

#### Change Admin Password
```bash
# Login to ArgoCD CLI
argocd login <NODE_IP>:30443

# Change password
argocd account update-password
```

#### Enable TLS (Production)
1. Remove `--insecure` flag from server args
2. Configure TLS certificates in `argocd-tls-certs-cm`
3. Update service to use HTTPS

## ArgoCD CLI Installation

### Install CLI
```bash
# Linux/macOS
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Or using package managers
# macOS: brew install argocd
# Linux: See ArgoCD docs for distro-specific instructions
```

### CLI Usage
```bash
# Login
argocd login <NODE_IP>:30443

# List applications
argocd app list

# Create application
argocd app create my-app \
  --repo https://github.com/example/my-app \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Sync application
argocd app sync my-app

# Get application status
argocd app get my-app
```

## Creating Applications

### Via CLI
```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

### Via YAML
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Repository Management

### Add Git Repository
```bash
# Public repository
argocd repo add https://github.com/example/my-repo

# Private repository with SSH
argocd repo add git@github.com:example/my-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Private repository with HTTPS
argocd repo add https://github.com/example/my-repo.git \
  --username myuser \
  --password mytoken
```

### Add Helm Repository
```bash
argocd repo add https://charts.example.com \
  --type helm \
  --name my-helm-repo
```

## Cluster Management

### Add External Cluster
```bash
# Add cluster using kubeconfig
argocd cluster add my-cluster-context

# List clusters
argocd cluster list

# Remove cluster
argocd cluster rm https://my-cluster-server
```

## RBAC Configuration

### Default Roles
- **admin**: Full access to all resources
- **readonly**: Read-only access to all resources

### Custom RBAC
Edit the `argocd-rbac-cm` ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Custom policies
    p, role:developers, applications, get, */*, allow
    p, role:developers, applications, sync, */*, allow
    g, developer-team, role:developers
```

## Monitoring and Observability

### Health Checks
```bash
# Check component status
kubectl get pods -n argocd

# Check application health
argocd app list

# View application details
argocd app get <app-name>
```

### Metrics
ArgoCD exposes Prometheus metrics on the following endpoints:
- Application Controller: `:8082/metrics`
- Repo Server: `:8084/metrics`
- Server: `:8083/metrics`

### Logs
```bash
# Server logs
kubectl logs -f deployment/argocd-server -n argocd

# Application controller logs
kubectl logs -f deployment/argocd-application-controller -n argocd

# Repo server logs
kubectl logs -f deployment/argocd-repo-server -n argocd
```

## GitOps Workflow

### 1. Repository Structure
```
my-app/
├── manifests/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── charts/
│   └── my-app/
└── environments/
    ├── dev/
    ├── staging/
    └── prod/
```

### 2. Application Configuration
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/my-app
    targetRevision: HEAD
    path: environments/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### 3. Deployment Process
1. **Developer pushes code** → Git repository
2. **CI/CD pipeline** → Builds and pushes image
3. **CI/CD updates** → Kubernetes manifests
4. **ArgoCD detects** → Changes in Git
5. **ArgoCD syncs** → Application to cluster

## Advanced Configuration

### Projects
```bash
# Create project
argocd proj create my-project \
  --description "My project" \
  --src https://github.com/example/* \
  --dest https://kubernetes.default.svc,my-namespace
```

### Sync Policies
```yaml
syncPolicy:
  automated:
    prune: true      # Remove resources not in Git
    selfHeal: true   # Revert manual changes
  syncOptions:
  - CreateNamespace=true
  - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### Hooks
```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

## Backup and Recovery

### Backup
```bash
# Backup ArgoCD configuration
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml
kubectl get secrets -n argocd -o yaml > argocd-secrets-backup.yaml
kubectl get configmaps -n argocd -o yaml > argocd-config-backup.yaml
```

### Disaster Recovery
```bash
# Restore applications
kubectl apply -f argocd-apps-backup.yaml

# Restore configuration
kubectl apply -f argocd-config-backup.yaml
kubectl apply -f argocd-secrets-backup.yaml

# Restart ArgoCD components
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-application-controller -n argocd
```

## Troubleshooting

### Common Issues

#### 1. Application OutOfSync
```bash
# Check application status
argocd app get <app-name>

# Manual sync
argocd app sync <app-name>

# Hard refresh
argocd app sync <app-name> --force
```

#### 2. Repository Connection Issues
```bash
# Test repository connection
argocd repo get <repo-url>

# Update repository credentials
argocd repo add <repo-url> --username <user> --password <token>
```

#### 3. Cluster Connection Issues
```bash
# Check cluster status
argocd cluster list

# Update cluster config
kubectl config current-context
argocd cluster add <context-name>
```

#### 4. Permission Issues
```bash
# Check RBAC configuration
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# Check service account permissions
kubectl auth can-i --list --as=system:serviceaccount:argocd:argocd-application-controller
```

### Debug Commands
```bash
# Check pod status
kubectl get pods -n argocd

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Port forward for local access
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Check application sync status
argocd app wait <app-name> --health
```

## Scaling

### High Availability
```yaml
# Scale components for HA
spec:
  replicas: 3  # For argocd-server
  replicas: 2  # For argocd-repo-server
  # Keep application-controller at 1 (leader election)
```

### Performance Tuning
```yaml
# Increase controller resources
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

# Tune sync settings
args:
- --status-processors=40
- --operation-processors=20
- --app-resync=300
```

## Integration Examples

### With Gitea
```bash
# Add Gitea repository
argocd repo add http://gitea.gitea.svc.cluster.local:3000/user/repo.git \
  --username gitea-user \
  --password gitea-token
```

### With CI/CD Pipelines
```yaml
# GitLab CI example
deploy:
  script:
    - argocd app sync my-app --grpc-web
    - argocd app wait my-app --health
```

## Cleanup

```bash
# Remove all applications first
argocd app delete --all

# Remove ArgoCD
kubectl delete -f argocd-deployment.yaml

# Remove namespace
kubectl delete namespace argocd
```

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD GitHub](https://github.com/argoproj/argo-cd)
- [GitOps Best Practices](https://www.gitops.tech/)
- [ArgoCD Examples](https://github.com/argoproj/argocd-example-apps)