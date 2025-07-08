# Nirmata N4K ArgoCD Deployment

This repository contains the ArgoCD applications for deploying Nirmata's N4K (Nirmata for Kubernetes) stack including Kyverno, Nirmata Kyverno Operator, and Nirmata Kube Controller.

## Applications Overview

### 1. Kyverno
- **Chart Version**: 3.3.18
- **App Version**: v1.13.6-n4k.nirmata.1
- **Description**: Kubernetes Native Policy Management
- **Namespace**: kyverno
- **Dependencies**: reports-server, grafana, crds

### 2. Nirmata Kyverno Operator
- **Chart Version**: v0.7.0
- **App Version**: v0.4.7
- **Description**: Helm Chart for Enterprise Kyverno Operator
- **Namespace**: nirmata-kyverno-operator
- **Dependencies**: crds

### 3. Nirmata Kube Controller
- **Chart Version**: 0.2.5
- **App Version**: v3.10.9
- **Description**: Nirmata Kubernetes Controller
- **Namespace**: nirmata

## Prerequisites

- Kubernetes cluster (>=1.22.0-0)
- ArgoCD installed and configured
- AWS CLI configured for ECR access
- Docker for building and pushing images
- Helm 3.x

## Container Images

The following container images need to be pushed to your ECR repository:

- `ghcr.io/nirmata/nirmata-kube-controller:v3.10.9`
- `ghcr.io/nirmata/opentelemetry-collector:0.92.0`
- `ghcr.io/nirmata/nirmata-kyverno-operator:v0.4.7`
- `ghcr.io/nirmata/nirmata-kyverno-operator:v0.4.7-rc3`
- `ghcr.io/nirmata/etcd:v3.5.18-cve-free`
- `ghcr.io/nirmata/kubectl:1.30.2`
- `reg.nirmata.io/nirmata/kyverno:v1.13.6-n4k.nirmata.1`
- `reg.nirmata.io/nirmata/kyvernopre:v1.13.6-n4k.nirmata.1`
- `reg.nirmata.io/nirmata/background-controller:v1.13.6-n4k.nirmata.1`
- `reg.nirmata.io/nirmata/cleanup-controller:v1.13.6-n4k.nirmata.1`
- `reg.nirmata.io/nirmata/reports-controller:v1.13.6-n4k.nirmata.1`
- `reg.nirmata.io/nirmata/reports-server:v0.1.19`
- `reg.nirmata.io/nirmata/kyverno-cli:v1.13.6-n4k.nirmata.1`
- `reg.nirmata.io/nirmata/kubectl:1.31.1`

## Quick Start

### 1. Set up ECR Repository

```bash
# Set your AWS region and account ID
export AWS_REGION="your-region"
export AWS_ACCOUNT_ID="your-account-id"

# Run the ECR setup script
./scripts/setup-ecr.sh
```

### 2. Push Images to ECR

```bash
# Authenticate Docker with ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Push all images
./scripts/push-images-to-ecr.sh
```

### 3. Deploy Applications with ArgoCD

```bash
# Apply the ArgoCD application manifests
kubectl apply -f argocd/
```

## ArgoCD Applications

All applications are configured to:
- Automatically sync with the main branch
- Self-heal on configuration drift
- Prune resources when removed from git
- Create namespaces if they don't exist

### Application URLs
- Repository: `https://github.com/anuddeeph1/onboard-n4k-argo.git`
- Target Revision: `main`
- ArgoCD Namespace: `argocd`

## Directory Structure

```
.
├── README.md                     # This documentation
├── argocd/                       # ArgoCD application manifests
│   ├── kyverno-app.yaml
│   ├── nirmata-kyverno-operator-app.yaml
│   └── nirmata-kube-controller-app.yaml
├── scripts/                      # Deployment scripts
│   ├── setup-ecr.sh
│   ├── push-images-to-ecr.sh
│   └── deploy-apps.sh
├── kyverno/                      # Kyverno Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── charts/
├── nirmata-kyverno-operator/     # Nirmata Kyverno Operator Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   ├── charts/
│   └── crds/
└── nirmata-kube-controller/      # Nirmata Kube Controller Helm chart
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

## Configuration

### Environment Variables

Create a `.env` file or set the following environment variables:

```bash
# AWS Configuration
export AWS_REGION="us-west-2"
export AWS_ACCOUNT_ID="123456789012"

# ECR Repository Configuration
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
export ECR_REPO_PREFIX="nirmata"

# Nirmata Registry Credentials (for private images)
export NIRMATA_REGISTRY_USERNAME="your-username"
export NIRMATA_REGISTRY_PASSWORD="your-password"
```

### Helm Values Customization

Each application has its own `values.yaml` file that can be customized:

- `kyverno/values.yaml` - Kyverno policy engine configuration
- `nirmata-kyverno-operator/values.yaml` - Operator configuration
- `nirmata-kube-controller/values.yaml` - Controller configuration

## Monitoring and Troubleshooting

### Check ArgoCD Application Status

```bash
# List all applications
argocd app list

# Get detailed status
argocd app get kyverno
argocd app get nirmata-kyverno-operator
argocd app get nirmata-kube-controller

# Sync applications manually
argocd app sync kyverno
```

### View Logs

```bash
# Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno

# Operator logs
kubectl logs -n nirmata-kyverno-operator -l app.kubernetes.io/name=nirmata-kyverno-operator

# Controller logs
kubectl logs -n nirmata -l app.kubernetes.io/name=nirmata-kube-controller
```

### Common Issues

1. **Image Pull Errors**: Ensure ECR authentication is working and images are properly tagged
2. **Namespace Issues**: Verify that the target namespaces exist or have `CreateNamespace=true` in sync options
3. **RBAC Issues**: Check that ArgoCD has proper permissions to deploy to target namespaces

## Contributing

1. Make changes to the Helm charts or ArgoCD configurations
2. Test changes in a development environment
3. Create a pull request with detailed description
4. Ensure all tests pass before merging

## Support

For issues related to:
- **Kyverno**: [Kyverno Documentation](https://kyverno.io/docs)
- **Nirmata Products**: [Nirmata Support](https://nirmata.com/support)
- **ArgoCD**: [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## License

This project follows the licensing terms of the respective components:
- Kyverno: Apache 2.0
- Nirmata Products: Commercial License