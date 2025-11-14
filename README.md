# Nirmata N4K ArgoCD Deployment

This repository contains the ArgoCD applications for deploying Nirmata's N4K (Nirmata enterprise kyverno) stack including Kyverno and Nirmata Kyverno Operator.

## Applications Overview

### 1. Kyverno

* **Chart Version**: 3.3.37
* **App Version**: v1.13.6-n4k.nirmata.10
* **Description**: Kubernetes Native Policy Management
* **Namespace**: kyverno
* **Dependencies**: reports-server, grafana, crds

### 2. Nirmata Kyverno Operator

* **Chart Version**: 0.8.8
* **App Version**: v0.4.13
* **Description**: Helm Chart for Enterprise Kyverno Operator
* **Namespace**: nirmata-system
* **Dependencies**: crds

## Prerequisites

* Kubernetes cluster (>=1.22.0-0)
* ArgoCD installed and configured
* AWS CLI configured for ECR access
* Docker for building and pushing images
* Helm 3.x

## Container Images

The following container images need to be pushed to your ECR repository:

### Nirmata Kyverno Operator Images
* `ghcr.io/nirmata/nirmata-kyverno-operator:v0.4.13`

### Kyverno Images
* `reg.nirmata.io/nirmata/kyverno:v1.13.6-n4k.nirmata.10`
* `reg.nirmata.io/nirmata/kyvernopre:v1.13.6-n4k.nirmata.10`
* `reg.nirmata.io/nirmata/background-controller:v1.13.6-n4k.nirmata.10`
* `reg.nirmata.io/nirmata/cleanup-controller:v1.13.6-n4k.nirmata.10`
* `reg.nirmata.io/nirmata/reports-controller:v1.13.6-n4k.nirmata.10`
* `reg.nirmata.io/nirmata/reports-server:v0.2.8`
* `reg.nirmata.io/nirmata/kyverno-cli:v1.13.6-n4k.nirmata.10`

### Supporting Images
* `ghcr.io/nirmata/etcd:v3.5.18-cve-free`
* `ghcr.io/nirmata/kubectl:1.30.2`

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

* Automatically sync with the main branch
* Self-heal on configuration drift
* Prune resources when removed from git
* Create namespaces if they don't exist

### Application URLs

* Repository: `https://github.com/nirmata/onboard-n4k-argo.git`
* Target Revision: `kyverno-3.3.37`
* ArgoCD Namespace: `argocd`

## Directory Structure

```
.
├── README.md                     # This documentation
├── argocd/                       # ArgoCD application manifests
│   ├── kyverno.yaml              # Kyverno ArgoCD application
│   ├── kyverno-operator.yaml     # Nirmata Kyverno Operator ArgoCD application
│   ├── README.md                 # ArgoCD deployment guide
│   ├── QUICKSTART.md             # Quick start guide
│   └── monitor-deployment.sh     # Monitoring script
├── kyverno/                      # Kyverno Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── charts/
│       ├── reports-server/       # Reports server subchart
│       ├── grafana/              # Grafana subchart
│       └── crds/                 # CRDs subchart
└── nirmata-kyverno-operator/     # Nirmata Kyverno Operator Helm chart
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    ├── charts/
    │   └── crds/                 # CRDs subchart
    └── crds/                     # Operator CRDs
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

* `kyverno/values.yaml` - Kyverno policy engine configuration
* `nirmata-kyverno-operator/values.yaml` - Operator configuration

You can override values directly in the ArgoCD application manifests or by modifying the values files in the repository.

## Monitoring and Troubleshooting

### Check ArgoCD Application Status

```bash
# List all applications
argocd app list

# Get detailed status
argocd app get kyverno
argocd app get nirmata-kyverno-operator

# Sync applications manually
argocd app sync nirmata-kyverno-operator
argocd app sync kyverno
```

### View Logs

```bash
# Kyverno admission controller logs
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller

# Kyverno background controller logs
kubectl logs -n kyverno -l app.kubernetes.io/component=background-controller

# Kyverno reports controller logs
kubectl logs -n kyverno -l app.kubernetes.io/component=reports-controller

# Operator logs
kubectl logs -n nirmata-system -l app.kubernetes.io/name=nirmata-kyverno-operator
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

* **Kyverno**: [Kyverno Documentation](https://kyverno.io/docs)
* **Nirmata Products**: [Nirmata Support](https://nirmata.com/support)
* **ArgoCD**: [ArgoCD Documentation](https://argo-cd.readthedocs.io)

## License

This project follows the licensing terms of the respective components:

* Kyverno: Apache 2.0
* Nirmata Products: Commercial License
