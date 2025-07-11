# Cleanup Guide for Kyverno and Nirmata Components

This guide provides comprehensive instructions for cleaning up all resources created by the Kyverno and Nirmata charts deployed via ArgoCD.

## Overview

The charts in this repository create the following components:
- **Kyverno**: Policy engine for Kubernetes
- **Nirmata Kyverno Operator**: Operator for managing Kyverno lifecycle
- **Nirmata Kube Controller**: Controller for cluster onboarding
- **Reports Server**: Server for storing and serving policy reports

## Cleanup Scripts

Two cleanup scripts are provided:

### 1. Complete Cleanup Script
**File**: `scripts/cleanup-all-resources.sh`

This script deletes **ALL** resources created by the charts.

#### Usage
```bash
# Delete everything
./scripts/cleanup-all-resources.sh

# Delete everything without confirmation
./scripts/cleanup-all-resources.sh --force

# Delete only specific types
./scripts/cleanup-all-resources.sh --argocd-only
./scripts/cleanup-all-resources.sh --crds-only
./scripts/cleanup-all-resources.sh --cluster-only
./scripts/cleanup-all-resources.sh --namespaces-only

# Skip specific types
./scripts/cleanup-all-resources.sh --skip-argocd
./scripts/cleanup-all-resources.sh --skip-crds
./scripts/cleanup-all-resources.sh --skip-cluster
./scripts/cleanup-all-resources.sh --skip-namespaces

# Dry run (see what would be deleted)
./scripts/cleanup-all-resources.sh --dry-run
```

### 2. Individual Component Cleanup Script
**File**: `scripts/cleanup-individual-components.sh`

This script allows you to delete individual components while preserving others.

#### Usage
```bash
# Delete individual components
./scripts/cleanup-individual-components.sh kyverno
./scripts/cleanup-individual-components.sh nirmata-kyverno-operator
./scripts/cleanup-individual-components.sh nirmata-kube-controller
./scripts/cleanup-individual-components.sh reports-server

# Delete without confirmation
./scripts/cleanup-individual-components.sh kyverno --force
```

## What Gets Deleted

### ArgoCD Applications
- `kyverno` (in `argocd` namespace)
- `nirmata-kyverno-operator` (in `argocd` namespace)
- `nirmata-kube-controller` (in `argocd` namespace)
- `reports-server` (in `argocd` namespace)

### Namespaces
- `kyverno` - Contains Kyverno components and Reports Server
- `nirmata-system` - Contains Nirmata Kyverno Operator
- `nirmata` - Contains Nirmata Kube Controller

### Custom Resource Definitions (CRDs)
- `policies.kyverno.io`
- `clusterpolicies.kyverno.io`
- `cleanuppolicies.kyverno.io`
- `clustercleanuppolicies.kyverno.io`
- `policyexceptions.kyverno.io`
- `globalcontextentries.kyverno.io`
- `updaterequests.kyverno.io`
- `ephemeralreports.reports.kyverno.io`
- `clusterephemeralreports.reports.kyverno.io`
- `policyreports.wgpolicyk8s.io`
- `clusterpolicyreports.wgpolicyk8s.io`
- `kyvernoconfigs.security.nirmata.io`
- `policysets.security.nirmata.io`

### Cluster-Level Resources
#### ClusterRoles and ClusterRoleBindings
- `kyverno:admission-controller`
- `kyverno:background-controller`
- `kyverno:cleanup-controller`
- `kyverno:reports-controller`
- `kyverno:admission-controller:core`
- `kyverno:background-controller:core`
- `kyverno:cleanup-controller:core`
- `kyverno:reports-controller:core`
- `kyverno:admission-controller:additional`
- `kyverno:background-controller:additional`
- `kyverno:cleanup-controller:additional`
- `kyverno:reports-controller:additional`
- `nirmata-kyverno-operator`
- `nirmata:readonly`
- `nirmata:policy-exceptions`
- `nirmata:policy-sets`
- `nirmata:readonly-binding`
- `nirmata:policy-exceptions-binding`
- `nirmata:policy-sets-binding`
- `reports-server`

#### Webhook Configurations
- ValidatingWebhookConfigurations with label `app.kubernetes.io/part-of=kyverno`
- MutatingWebhookConfigurations with label `app.kubernetes.io/part-of=kyverno`
- `kyverno-operator-validating-webhook-configuration`

#### API Services
- `v1.reports.kyverno.io`
- `v1alpha2.wgpolicyk8s.io`

#### Flow Control Resources
- FlowSchemas with label `app.kubernetes.io/part-of=kyverno`
- PriorityLevelConfigurations with label `app.kubernetes.io/part-of=kyverno`

### Custom Resources
- All Kyverno policies (`ClusterPolicy`, `Policy`)
- All cleanup policies (`ClusterCleanupPolicy`, `CleanupPolicy`)
- All policy exceptions (`PolicyException`)
- All global context entries (`GlobalContextEntry`)
- All update requests (`UpdateRequest`)
- All report resources (`EphemeralReport`, `ClusterEphemeralReport`, `PolicyReport`, `ClusterPolicyReport`)
- All Nirmata custom resources (`KyvernoConfig`, `PolicySet`)

## Component-Specific Cleanup

### Kyverno Component
**Resources deleted:**
- ArgoCD application: `kyverno`
- All Kyverno policies and configurations
- Kyverno CRDs and their resources
- Kyverno cluster-level resources (ClusterRoles, ClusterRoleBindings, Webhooks)
- Kyverno resources in the `kyverno` namespace (excluding Reports Server)

### Nirmata Kyverno Operator Component
**Resources deleted:**
- ArgoCD application: `nirmata-kyverno-operator`
- Nirmata custom resources (`kyvernoconfigs`, `policysets`)
- Nirmata CRDs
- Operator cluster-level resources
- Entire `nirmata-system` namespace and all its resources

### Nirmata Kube Controller Component
**Resources deleted:**
- ArgoCD application: `nirmata-kube-controller`
- Nirmata cluster-level resources
- Entire `nirmata` namespace and all its resources

### Reports Server Component
**Resources deleted:**
- ArgoCD application: `reports-server`
- All report resources
- APIServices for reports
- Reports Server resources in the `kyverno` namespace
- ETCD StatefulSet and related resources

## Pre-Cleanup Verification

Before running cleanup scripts, you can verify what resources exist:

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check namespaces
kubectl get namespaces | grep -E '(kyverno|nirmata)'

# Check CRDs
kubectl get crd | grep -E '(kyverno|nirmata)'

# Check cluster roles
kubectl get clusterroles | grep -E '(kyverno|nirmata)'

# Check cluster role bindings
kubectl get clusterrolebindings | grep -E '(kyverno|nirmata)'

# Check webhook configurations
kubectl get validatingwebhookconfigurations | grep -E '(kyverno|nirmata)'
kubectl get mutatingwebhookconfigurations | grep -E '(kyverno|nirmata)'

# Check API services
kubectl get apiservices | grep -E '(kyverno|wgpolicyk8s)'

# Check policies
kubectl get clusterpolicies
kubectl get policies --all-namespaces

# Check custom resources
kubectl get kyvernoconfigs --all-namespaces
kubectl get policysets --all-namespaces
```

## Post-Cleanup Verification

After running cleanup scripts, verify that resources have been deleted:

```bash
# Check for remaining resources
kubectl get all --all-namespaces | grep -E '(kyverno|nirmata)'
kubectl get crd | grep -E '(kyverno|nirmata)'
kubectl get clusterroles | grep -E '(kyverno|nirmata)'
kubectl get clusterrolebindings | grep -E '(kyverno|nirmata)'
kubectl get applications -n argocd

# Check for remaining namespaces
kubectl get namespaces | grep -E '(kyverno|nirmata)'

# Check for remaining webhooks
kubectl get validatingwebhookconfigurations | grep -E '(kyverno|nirmata)'
kubectl get mutatingwebhookconfigurations | grep -E '(kyverno|nirmata)'
```

## Safe Cleanup Order

If you need to manually clean up resources, follow this order:

1. **Delete ArgoCD applications** (prevents re-creation)
2. **Delete custom resources** (policies, configs, etc.)
3. **Delete CRDs** (after their resources are deleted)
4. **Delete cluster-level resources** (ClusterRoles, ClusterRoleBindings, Webhooks)
5. **Delete namespaced resources**
6. **Delete namespaces**

## Troubleshooting

### Resources Stuck in Terminating State
If resources are stuck in terminating state, you can try:

```bash
# Remove finalizers from stuck resources
kubectl patch <resource-type> <resource-name> -n <namespace> --type='merge' -p='{"metadata":{"finalizers":[]}}'

# Force delete with grace period
kubectl delete <resource-type> <resource-name> -n <namespace> --grace-period=0 --force
```

### Namespace Stuck in Terminating State
```bash
# Remove finalizers from namespace
kubectl patch namespace <namespace> --type='merge' -p='{"metadata":{"finalizers":[]}}'

# Check for remaining resources in namespace
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n <namespace>
```

### CRDs Not Deleting
```bash
# Check if CRD has finalizers
kubectl get crd <crd-name> -o yaml | grep finalizers

# Remove finalizers if necessary
kubectl patch crd <crd-name> --type='merge' -p='{"metadata":{"finalizers":[]}}'
```

## Backup Before Cleanup

Before running cleanup scripts, consider backing up important resources:

```bash
# Backup all policies
kubectl get clusterpolicies -o yaml > clusterpolicies-backup.yaml
kubectl get policies --all-namespaces -o yaml > policies-backup.yaml

# Backup custom resources
kubectl get kyvernoconfigs --all-namespaces -o yaml > kyvernoconfigs-backup.yaml
kubectl get policysets --all-namespaces -o yaml > policysets-backup.yaml

# Backup ArgoCD applications
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml
```

## Support

If you encounter issues during cleanup:

1. Check the logs of the cleanup scripts
2. Verify your kubectl configuration and cluster access
3. Ensure you have sufficient permissions to delete cluster-level resources
4. Use the verification commands to identify any remaining resources

## Warning

**⚠️ IMPORTANT**: The cleanup scripts will permanently delete all resources created by the charts. This action cannot be undone. Always backup important configurations before running cleanup scripts.

Make sure you understand what will be deleted and have appropriate backups before proceeding with cleanup operations. 