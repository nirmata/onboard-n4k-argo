# Deployment Guide: Nirmata N4K with ArgoCD

This guide provides step-by-step instructions for deploying the Nirmata N4K stack using ArgoCD.

## Overview

This deployment includes three main applications:
1. **Kyverno** - Kubernetes native policy management
2. **Nirmata Kyverno Operator** - Enterprise Kyverno operator
3. **Nirmata Kube Controller** - Nirmata Kubernetes controller

## Prerequisites

### Required Tools
- `kubectl` (>= 1.22)
- `aws` CLI (>= 2.0)
- `docker` (>= 20.0)
- `helm` (>= 3.0)

### Required Access
- Kubernetes cluster with admin privileges
- AWS account with ECR permissions
- Nirmata registry credentials (for private images)

## Step 1: Environment Setup

1. **Clone the repository** (if not already done):
   ```bash
   git clone https://github.com/anuddeeph1/onboard-n4k-argo.git
   cd onboard-n4k-argo
   ```

2. **Configure environment variables**:
   ```bash
   # Copy the template
   cp env.template .env
   
   # Edit the .env file with your values
   nano .env
   ```

3. **Load environment variables**:
   ```bash
   source .env
   ```

## Step 2: Install ArgoCD (if not already installed)

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

## Step 3: Set Up ECR Repositories

1. **Create ECR repositories**:
   ```bash
   ./scripts/setup-ecr.sh
   ```

2. **Verify repositories were created**:
   ```bash
   aws ecr describe-repositories --region $AWS_REGION --query 'repositories[].repositoryName' --output table
   ```

## Step 4: Push Container Images to ECR

1. **Authenticate with Nirmata registry** (for private images):
   ```bash
   docker login reg.nirmata.io -u $NIRMATA_REGISTRY_USERNAME -p $NIRMATA_REGISTRY_PASSWORD
   ```

2. **Push all images to ECR**:
   ```bash
   ./scripts/push-images-to-ecr.sh
   ```

   This script will:
   - Pull images from source registries
   - Tag them for your ECR
   - Push them to ECR repositories

## Step 5: Update Helm Values (Optional)

If you want to use ECR images instead of the original registries, update the values files:

```bash
# Example: Update kyverno values to use ECR images
sed -i '' "s|ghcr.io/nirmata|$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/nirmata|g" kyverno/values.yaml
```

## Step 6: Deploy Applications with ArgoCD

1. **Deploy all applications**:
   ```bash
   ./scripts/deploy-apps.sh
   ```

2. **Verify deployment**:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n kyverno
   kubectl get pods -n nirmata-kyverno-operator
   kubectl get pods -n nirmata
   ```

## Step 7: Access ArgoCD UI

1. **Get ArgoCD admin password**:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
   ```

2. **Port forward to ArgoCD UI**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

3. **Access UI**:
   - URL: https://localhost:8080
   - Username: `admin`
   - Password: (from step 1)

## Step 8: Monitor Applications

### Check Application Status
```bash
# List all applications
kubectl get applications -n argocd

# Get detailed status
kubectl get application kyverno -n argocd -o yaml
kubectl get application nirmata-kyverno-operator -n argocd -o yaml
kubectl get application nirmata-kube-controller -n argocd -o yaml
```

### Check Pod Status
```bash
# Kyverno pods
kubectl get pods -n kyverno -l app.kubernetes.io/name=kyverno

# Operator pods
kubectl get pods -n nirmata-kyverno-operator

# Controller pods
kubectl get pods -n nirmata
```

### View Logs
```bash
# Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno -f

# Operator logs
kubectl logs -n nirmata-kyverno-operator -l app.kubernetes.io/name=nirmata-kyverno-operator -f

# Controller logs
kubectl logs -n nirmata -l app.kubernetes.io/name=nirmata-kube-controller -f
```

## Troubleshooting

### Common Issues

1. **Image Pull Errors**:
   - Verify ECR authentication: `aws ecr get-login-password --region $AWS_REGION`
   - Check image exists: `aws ecr describe-images --repository-name nirmata/kyverno --region $AWS_REGION`

2. **Application Sync Issues**:
   - Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`
   - Manual sync: `kubectl patch application kyverno -n argocd --type='merge' -p='{"operation":{"sync":{}}}'`

3. **Namespace Creation Issues**:
   - Manually create namespace: `kubectl create namespace kyverno`
   - Check RBAC permissions for ArgoCD

4. **Helm Chart Issues**:
   - Validate Helm charts: `helm template kyverno ./kyverno/`
   - Check values file syntax: `helm lint ./kyverno/`

### Useful Commands

```bash
# Force application sync
argocd app sync kyverno

# Get application details
argocd app get kyverno

# Restart application deployment
kubectl rollout restart deployment/kyverno -n kyverno

# Check ArgoCD server status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
```

## Customization

### Modifying Helm Values

Each application can be customized by modifying its `values.yaml` file:

- `kyverno/values.yaml` - Kyverno configuration
- `nirmata-kyverno-operator/values.yaml` - Operator configuration  
- `nirmata-kube-controller/values.yaml` - Controller configuration

After making changes, ArgoCD will automatically detect and sync the changes.

### Adding Custom Policies

To add custom Kyverno policies:

1. Create policy files in `kyverno/templates/policies/`
2. Commit changes to git
3. ArgoCD will automatically apply the new policies

## Cleanup

To remove all applications:

```bash
# Delete ArgoCD applications
kubectl delete application kyverno nirmata-kyverno-operator nirmata-kube-controller -n argocd

# Delete namespaces (optional)
kubectl delete namespace kyverno nirmata-kyverno-operator nirmata
```

## Security Considerations

1. **Image Security**: All images are scanned in ECR with `scanOnPush=true`
2. **Network Policies**: Consider implementing network policies for namespace isolation
3. **RBAC**: Review and customize RBAC permissions in Helm values
4. **Secrets Management**: Use Kubernetes secrets or external secret management for sensitive data

## Support

For issues or questions:
- **Kyverno**: [Kyverno Slack](https://kubernetes.slack.com/channels/kyverno)
- **Nirmata**: [Nirmata Support](https://nirmata.com/support)
- **ArgoCD**: [ArgoCD GitHub Issues](https://github.com/argoproj/argo-cd/issues) 