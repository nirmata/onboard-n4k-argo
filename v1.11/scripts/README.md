# Cleanup Scripts

This directory contains scripts to help manage and clean up resources created by the Nirmata Kube Controller and Kyverno Operator.

## cleanup-all-resources.sh

A comprehensive cleanup script that removes all resources created by the Nirmata Kube Controller and Kyverno Operator.

### Features

- **Comprehensive cleanup**: Removes all related resources including CRDs, APIServices, webhooks, cluster roles, namespaces, and ArgoCD applications
- **Selective cleanup**: Options to clean only specific components
- **Safety features**: Confirmation prompts, dry-run mode, and graceful error handling
- **Colored output**: Easy-to-read colored output for different message types
- **Flexible options**: Multiple command-line options for different use cases

### Usage

```bash
# Make the script executable (if not already)
chmod +x scripts/cleanup-all-resources.sh

# Run with different options
./scripts/cleanup-all-resources.sh [OPTIONS]
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--argocd-only` | Delete only ArgoCD applications |
| `--crds-only` | Delete only CRDs and their resources |
| `--cluster-only` | Delete only cluster-level resources |
| `--namespaces-only` | Delete only namespaced resources and namespaces |
| `--force-cleanup` | Force cleanup any remaining kyverno/nirmata resources |
| `--skip-argocd` | Skip deleting ArgoCD applications |
| `--skip-crds` | Skip deleting CRDs |
| `--skip-cluster` | Skip deleting cluster-level resources |
| `--skip-namespaces` | Skip deleting namespaces |
| `--dry-run` | Show what would be deleted without actually deleting |
| `--force` | Skip confirmation prompts |
| `-h, --help` | Show help message |

### Examples

#### Complete cleanup
```bash
# Delete everything with confirmation
./scripts/cleanup-all-resources.sh

# Delete everything without confirmation
./scripts/cleanup-all-resources.sh --force
```

#### Selective cleanup
```bash
# Delete only ArgoCD applications
./scripts/cleanup-all-resources.sh --argocd-only

# Delete only CRDs and their resources
./scripts/cleanup-all-resources.sh --crds-only

# Delete only cluster-level resources
./scripts/cleanup-all-resources.sh --cluster-only

# Delete only namespaced resources
./scripts/cleanup-all-resources.sh --namespaces-only
```

#### Skip specific components
```bash
# Delete everything except ArgoCD applications
./scripts/cleanup-all-resources.sh --skip-argocd

# Delete everything except CRDs
./scripts/cleanup-all-resources.sh --skip-crds

# Delete everything except namespaces
./scripts/cleanup-all-resources.sh --skip-namespaces
```

#### Preview mode
```bash
# See what would be deleted without actually deleting
./scripts/cleanup-all-resources.sh --dry-run
```

#### Force cleanup remaining resources
```bash
# Clean up any remaining kyverno/nirmata resources after previous cleanup attempts
./scripts/cleanup-all-resources.sh --force-cleanup
```

### What Gets Deleted

The script removes the following resources:

#### ArgoCD Applications
- `nirmata-kube-controller`
- `kyverno-operator`

#### Kyverno Resources
- All policies, clusterpolicies, policyexceptions
- All cleanup policies and cluster cleanup policies
- All admission reports and background scan reports
- All policy reports and cluster policy reports
- Global context entries and update requests

#### Nirmata Custom Resources
- All kyvernoconfigs
- All policysets
- All kyvernoadapters
- All kyvernooperators

#### Custom Resource Definitions (CRDs)
- `policies.kyverno.io`
- `clusterpolicies.kyverno.io`
- `cleanuppolicies.kyverno.io`
- `clustercleanuppolicies.kyverno.io`
- `policyexceptions.kyverno.io`
- `globalcontextentries.kyverno.io`
- `updaterequests.kyverno.io`
- `admissionreports.kyverno.io`
- `clusteradmissionreports.kyverno.io`
- `backgroundscanreports.kyverno.io`
- `clusterbackgroundscanreports.kyverno.io`
- `policyreports.wgpolicyk8s.io`
- `clusterpolicyreports.wgpolicyk8s.io`
- `kyvernoconfigs.security.nirmata.io`
- `policysets.security.nirmata.io`
- `kyvernoadapters.security.nirmata.io`
- `kyvernooperators.security.nirmata.io`

#### Cluster-Level Resources
- APIServices: `v1.reports.kyverno.io`, `v1alpha2.wgpolicyk8s.io`
- ValidatingWebhookConfigurations and MutatingWebhookConfigurations
- ClusterRoles and ClusterRoleBindings for Kyverno and Nirmata
- FlowSchemas and PriorityLevelConfigurations

#### Namespaces and Contents
- `kyverno` namespace and all its resources
- `nirmata-system` namespace and all its resources
- `nirmata` namespace and all its resources

### Safety Features

1. **Confirmation Prompt**: By default, the script asks for confirmation before deleting resources
2. **Dry Run Mode**: Use `--dry-run` to see what would be deleted without actually deleting
3. **Error Handling**: Uses `set -euo pipefail` for strict error handling
4. **Graceful Failures**: Continues execution even if some resources fail to delete
5. **Timeouts**: All delete operations have timeouts to prevent hanging

### Prerequisites

- `kubectl` must be installed and configured
- Must have sufficient permissions to delete cluster-level resources
- Must be connected to the correct Kubernetes cluster

### Verification

After running the cleanup script, you can verify that resources have been deleted using these commands:

```bash
# Check for remaining resources
kubectl get all --all-namespaces | grep -E '(kyverno|nirmata)'
kubectl get crd | grep -E '(kyverno|nirmata)'
kubectl get clusterroles | grep -E '(kyverno|nirmata)'
kubectl get clusterrolebindings | grep -E '(kyverno|nirmata)'
kubectl get applications -n argocd
kubectl get apiservices | grep -E '(kyverno|wgpolicyk8s)'
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno
```

### Troubleshooting

#### Remaining Resources After Cleanup
If you still see Kyverno or Nirmata resources after running the cleanup script, use the force cleanup option:

```bash
./scripts/cleanup-all-resources.sh --force-cleanup
```

This will search for and delete any remaining resources with "kyverno" or "nirmata" in their names.

#### Resources Stuck in Terminating State
Some resources might get stuck in "Terminating" state due to finalizers. The script attempts to remove finalizers automatically, but if issues persist:

```bash
# Manually remove finalizers from stuck resources
kubectl patch <resource-type> <resource-name> --type='merge' -p='{"metadata":{"finalizers":[]}}'

# For namespaces
kubectl patch namespace <namespace-name> --type='merge' -p='{"metadata":{"finalizers":[]}}'
```

#### Permission Issues
Ensure you have cluster-admin privileges or sufficient RBAC permissions to delete cluster-level resources.

#### Script Fails to Connect to Cluster
Verify your kubeconfig is properly configured:
```bash
kubectl cluster-info
kubectl config current-context
```

### Warning

⚠️ **This script performs destructive operations that cannot be undone. Always verify you're connected to the correct cluster and consider taking backups if needed.** 