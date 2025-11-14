# ArgoCD Applications for N4K

This directory contains ArgoCD Application manifests for deploying Nirmata N4K components.

## Quick Start

### Deploy All Applications

```bash
kubectl apply -f argocd/
```

This will create two ArgoCD applications:
1. **nirmata-kyverno-operator** - Enterprise Kyverno Operator (deployed first)
2. **kyverno** - Kyverno Policy Engine with all controllers

## Applications Included

### 1. Nirmata Kyverno Operator
- **Name**: `nirmata-kyverno-operator`
- **Namespace**: `nirmata-system`
- **Path**: `nirmata-kyverno-operator`
- **Chart Version**: 0.8.8
- **App Version**: v0.4.13
- **Description**: Enterprise Kyverno Operator that manages Kyverno installations
- **File**: `kyverno-operator.yaml`

### 2. Kyverno
- **Name**: `kyverno`
- **Namespace**: `kyverno`
- **Path**: `kyverno`
- **Chart Version**: 3.3.37
- **App Version**: v1.13.6-n4k.nirmata.10
- **Description**: Complete Kyverno installation including:
  - Admission Controller
  - Background Controller
  - Cleanup Controller
  - Reports Controller
  - Reports Server
  - CRDs
  - Grafana (optional)
- **File**: `kyverno.yaml`

## Prerequisites

1. **ArgoCD installed**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **Access to the Git repository**:
   - Repository: `https://github.com/nirmata/onboard-n4k-argo.git`
   - Branch: `kyverno-3.3.37`

## Deployment Steps

### Option 1: Deploy Both Applications at Once (Recommended)

```bash
# Deploy both applications
kubectl apply -f argocd/

# Both will be created and synced automatically by ArgoCD
# Note: It's recommended that the operator deploys first, but ArgoCD will handle the sync
```

### Option 2: Deploy Individually (Step-by-Step)

1. **Deploy Nirmata Kyverno Operator first**:
   ```bash
   kubectl apply -f argocd/kyverno-operator.yaml
   ```

2. **Wait for operator to be ready**:
   ```bash
   kubectl wait --for=condition=Available deployment/nirmata-kyverno-operator -n nirmata-system --timeout=300s
   ```

3. **Deploy Kyverno**:
   ```bash
   kubectl apply -f argocd/kyverno.yaml
   ```

### Verify Deployment

1. **Check application status**:
   ```bash
   # List applications
   kubectl get applications -n argocd
   
   # Get detailed status
   kubectl get application -n argocd nirmata-kyverno-operator -o yaml
   kubectl get application -n argocd kyverno -o yaml
   ```

2. **Verify pods are running**:
   ```bash
   # Check operator pods
   kubectl get pods -n nirmata-system
   
   # Check Kyverno pods
   kubectl get pods -n kyverno
   
   # Check Kyverno version
   kubectl get pods -n kyverno -l app.kubernetes.io/component=admission-controller -o jsonpath='{.items[0].spec.containers[0].image}'
   ```

## Using ArgoCD CLI

If you have ArgoCD CLI installed:

```bash
# Login to ArgoCD
argocd login <ARGOCD_SERVER>

# List applications
argocd app list

# Get application details
argocd app get nirmata-kyverno-operator
argocd app get kyverno

# Sync applications (operator first)
argocd app sync nirmata-kyverno-operator
argocd app sync kyverno

# Watch sync progress
argocd app wait nirmata-kyverno-operator
argocd app wait kyverno
```

## Access ArgoCD UI

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Open browser
open https://localhost:8080
```

## Configuration

### Sync Policies

Both applications are configured with:
- ✅ **Automated sync**: Changes in Git trigger automatic sync
- ✅ **Self-heal**: ArgoCD will revert manual changes
- ✅ **Prune**: Resources removed from Git will be deleted
- ✅ **ServerSideApply**: For handling large resources
- ✅ **CreateNamespace**: Automatically creates the target namespaces (`nirmata-system` and `kyverno`)
- ✅ **Replace**: Used for Kyverno to handle webhook configurations
- ✅ **Retry logic**: Both apps retry up to 5 times with exponential backoff

### Ignore Differences

The applications ignore certain resources that are dynamically managed:

**Kyverno Application:**
- API Services (v1.reports.kyverno.io, v1alpha2.wgpolicyk8s.io)
- StatefulSets (etcd storage and volume templates)
- Jobs (post-install hooks for API services)

**Kyverno Operator Application:**
- Secrets (webhook-server-cert with dynamic data)
- KyvernoConfig resources (dynamic annotations)
- ValidatingWebhookConfiguration (dynamic CA bundles)

## Customization

### Update Git Branch

To use a different branch, edit both application files:

```bash
# Edit the files
vim argocd/kyverno-operator.yaml
vim argocd/kyverno.yaml

# Change targetRevision in both files
spec:
  source:
    targetRevision: kyverno-3.3.37  # or your branch name
```

### Override Helm Values

To customize values inline:

```yaml
spec:
  source:
    helm:
      values: |
        admissionController:
          replicas: 3
        backgroundController:
          replicas: 2
```

Or create a custom values file in the repo and reference it:

```yaml
spec:
  source:
    helm:
      valueFiles:
        - values.yaml
        - values-production.yaml
```

## Troubleshooting

### Application Out of Sync

```bash
# Check differences
argocd app diff kyverno

# Force refresh
argocd app get kyverno --refresh

# Manual sync
argocd app sync kyverno --force
```

### Application Degraded

```bash
# Check application status
kubectl describe application -n argocd kyverno

# Check pod status
kubectl get pods -n kyverno
kubectl describe pod -n kyverno <pod-name>

# Check logs
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller
```

### Sync Failing

```bash
# Check sync operation
kubectl get application -n argocd kyverno -o jsonpath='{.status.operationState}'

# Delete and recreate
kubectl delete application -n argocd kyverno
kubectl apply -f argocd/kyverno.yaml
```

## Cleanup

To remove all applications:

```bash
# Delete Kyverno first
kubectl delete -f argocd/kyverno.yaml

# Wait for Kyverno to be removed
kubectl wait --for=delete namespace/kyverno --timeout=300s

# Delete operator
kubectl delete -f argocd/kyverno-operator.yaml

# Or delete individually
kubectl delete application -n argocd kyverno
kubectl delete application -n argocd nirmata-kyverno-operator

# Clean up namespaces if needed
kubectl delete namespace kyverno
kubectl delete namespace nirmata-system
```

## Notes

1. **Operator First**: Nirmata Kyverno Operator should be deployed before Kyverno
2. **CRDs**: Custom Resource Definitions are included in both charts
3. **Replace Option**: The `Replace=true` sync option is used for Kyverno to handle webhook configurations
4. **Namespaces**: 
   - Operator deploys to the `nirmata-system` namespace
   - Kyverno deploys to the `kyverno` namespace
5. **Reports Server**: Included as a subchart within the Kyverno chart
6. **Monitoring Script**: Use `./argocd/monitor-deployment.sh` to check deployment status

## References

- [Kyverno Documentation](https://kyverno.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kyverno ArgoCD Notes](https://kyverno.io/docs/installation/#notes-on-using-argocd)

