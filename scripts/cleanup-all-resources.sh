#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
}

# Function to safely delete resources
safe_delete() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-}"
    
    local cmd="kubectl delete $resource_type $resource_name"
    if [[ -n "$namespace" ]]; then
        cmd="$cmd -n $namespace"
    fi
    cmd="$cmd --ignore-not-found=true --timeout=60s"
    
    print_info "Deleting $resource_type/$resource_name"
    if ! $cmd; then
        print_warning "Failed to delete $resource_type/$resource_name"
    fi
}

# Function to delete ArgoCD applications
delete_argocd_apps() {
    print_step "Deleting ArgoCD Applications..."
    
    local apps=("kyverno" "kyverno-operator" "nirmata-kube-controller" "reports-server")
    
    for app in "${apps[@]}"; do
        if kubectl get application "$app" -n argocd &> /dev/null; then
            print_info "Deleting ArgoCD application: $app"
            
            # Remove finalizers first to allow deletion
            kubectl patch application "$app" -n argocd --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
            
            # Delete the application
            kubectl delete application "$app" -n argocd --timeout=60s || true
        else
            print_warning "ArgoCD application $app not found"
        fi
    done
    
    print_info "Waiting for ArgoCD applications to be deleted..."
    sleep 10
}

# Function to delete CRDs and their resources
delete_crds_and_resources() {
    print_step "Deleting CRDs and their resources..."
    
    # Delete Kyverno policy resources first
    print_info "Deleting Kyverno policy resources..."
    kubectl delete clusterpolicies --all --ignore-not-found=true --timeout=60s || true
    kubectl delete policies --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete cleanuppolicies --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clustercleanuppolicies --all --ignore-not-found=true --timeout=60s || true
    kubectl delete policyexceptions --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete globalcontextentries --all --ignore-not-found=true --timeout=60s || true
    kubectl delete updaterequests --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    
    # Delete report resources
    print_info "Deleting report resources..."
    kubectl delete ephemeralreports --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clusterephemeralreports --all --ignore-not-found=true --timeout=60s || true
    kubectl delete policyreports --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clusterpolicyreports --all --ignore-not-found=true --timeout=60s || true
    
    # Delete Nirmata custom resources
    print_info "Deleting Nirmata custom resources..."
    kubectl delete kyvernoconfigs --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete policysets --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    
    # Delete CRDs
    print_info "Deleting CRDs..."
    local crds=(
        "policies.kyverno.io"
        "clusterpolicies.kyverno.io"
        "cleanuppolicies.kyverno.io"
        "clustercleanuppolicies.kyverno.io"
        "policyexceptions.kyverno.io"
        "globalcontextentries.kyverno.io"
        "updaterequests.kyverno.io"
        "ephemeralreports.reports.kyverno.io"
        "clusterephemeralreports.reports.kyverno.io"
        "policyreports.wgpolicyk8s.io"
        "clusterpolicyreports.wgpolicyk8s.io"
        "kyvernoconfigs.security.nirmata.io"
        "policysets.security.nirmata.io"
    )
    
    for crd in "${crds[@]}"; do
        safe_delete "crd" "$crd"
    done
}

# Function to delete cluster-level resources
delete_cluster_resources() {
    print_step "Deleting cluster-level resources..."
    
    # Delete APIServices
    print_info "Deleting APIServices..."
    safe_delete "apiservice" "v1.reports.kyverno.io"
    safe_delete "apiservice" "v1alpha2.wgpolicyk8s.io"
    
    # Delete Webhook Configurations
    print_info "Deleting Webhook Configurations..."
    kubectl delete validatingwebhookconfigurations -l app.kubernetes.io/part-of=kyverno --ignore-not-found=true --timeout=60s || true
    kubectl delete mutatingwebhookconfigurations -l app.kubernetes.io/part-of=kyverno --ignore-not-found=true --timeout=60s || true
    kubectl delete validatingwebhookconfigurations kyverno-operator-validating-webhook-configuration --ignore-not-found=true --timeout=60s || true
    
    # Delete FlowSchemas and PriorityLevelConfigurations
    print_info "Deleting FlowSchemas and PriorityLevelConfigurations..."
    kubectl delete flowschemas -l app.kubernetes.io/part-of=kyverno --ignore-not-found=true --timeout=60s || true
    kubectl delete prioritylevelconfigurations -l app.kubernetes.io/part-of=kyverno --ignore-not-found=true --timeout=60s || true
    
    # Delete ClusterRoles and ClusterRoleBindings
    print_info "Deleting ClusterRoles and ClusterRoleBindings..."
    local cluster_roles=(
        "kyverno:admission-controller"
        "kyverno:background-controller"
        "kyverno:cleanup-controller"
        "kyverno:reports-controller"
        "kyverno:admission-controller:core"
        "kyverno:background-controller:core"
        "kyverno:cleanup-controller:core"
        "kyverno:reports-controller:core"
        "kyverno:admission-controller:additional"
        "kyverno:background-controller:additional"
        "kyverno:cleanup-controller:additional"
        "kyverno:reports-controller:additional"
        "nirmata-kyverno-operator"
        "nirmata:readonly"
        "nirmata:policy-exceptions"
        "nirmata:policy-sets"
        "reports-server"
    )
    
    for role in "${cluster_roles[@]}"; do
        safe_delete "clusterrole" "$role"
        safe_delete "clusterrolebinding" "$role"
    done
    
    # Delete additional cluster role bindings
    safe_delete "clusterrolebinding" "nirmata:readonly-binding"
    safe_delete "clusterrolebinding" "nirmata:policy-exceptions-binding"
    safe_delete "clusterrolebinding" "nirmata:policy-sets-binding"
}

# Function to delete namespaced resources
delete_namespaced_resources() {
    print_step "Deleting namespaced resources..."
    
    local namespaces=("kyverno" "nirmata-system" "nirmata")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            print_info "Deleting resources in namespace: $ns"
            
            # Delete all resources in namespace (except PVCs which need special handling)
            kubectl delete all --all -n "$ns" --ignore-not-found=true --timeout=120s || true
            
            # Delete PVCs
            kubectl delete pvc --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            
            # Delete secrets and configmaps
            kubectl delete secrets --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            kubectl delete configmaps --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            
            # Delete service accounts
            kubectl delete serviceaccounts --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            
            # Delete roles and rolebindings
            kubectl delete roles --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            kubectl delete rolebindings --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            
            # Delete network policies
            kubectl delete networkpolicies --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            
            # Delete pod disruption budgets
            kubectl delete poddisruptionbudgets --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            
        else
            print_warning "Namespace $ns not found"
        fi
    done
}

# Function to delete namespaces
delete_namespaces() {
    print_step "Deleting namespaces..."
    
    local namespaces=("kyverno" "nirmata-system" "nirmata")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            print_info "Deleting namespace: $ns"
            
            # Remove finalizers from namespace if stuck
            kubectl patch namespace "$ns" --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
            
            # Delete namespace
            kubectl delete namespace "$ns" --timeout=120s || true
        else
            print_warning "Namespace $ns not found"
        fi
    done
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Delete all resources created by the Kyverno and Nirmata charts."
    echo
    echo "Options:"
    echo "  --argocd-only         Delete only ArgoCD applications"
    echo "  --crds-only          Delete only CRDs and their resources"
    echo "  --cluster-only       Delete only cluster-level resources"
    echo "  --namespaces-only    Delete only namespaced resources"
    echo "  --skip-argocd        Skip deleting ArgoCD applications"
    echo "  --skip-crds          Skip deleting CRDs"
    echo "  --skip-cluster       Skip deleting cluster-level resources"
    echo "  --skip-namespaces    Skip deleting namespaces"
    echo "  --dry-run            Show what would be deleted without actually deleting"
    echo "  --force              Skip confirmation prompts"
    echo "  -h, --help           Show this help message"
    echo
    echo "Examples:"
    echo "  $0                   # Delete everything"
    echo "  $0 --argocd-only     # Delete only ArgoCD applications"
    echo "  $0 --skip-argocd     # Delete everything except ArgoCD applications"
    echo "  $0 --force           # Delete everything without confirmation"
}

# Function to confirm deletion
confirm_deletion() {
    if [[ "${FORCE:-false}" == "true" ]]; then
        return 0
    fi
    
    echo
    print_warning "This will delete ALL resources created by the Kyverno and Nirmata charts."
    print_warning "This includes:"
    echo "  - ArgoCD applications (kyverno, nirmata-kyverno-operator, nirmata-kube-controller, reports-server)"
    echo "  - All Kyverno policies and configurations"
    echo "  - All CRDs and their resources"
    echo "  - All cluster-level resources (ClusterRoles, ClusterRoleBindings, etc.)"
    echo "  - Namespaces: kyverno, nirmata-system, nirmata"
    echo "  - All resources within those namespaces"
    echo
    print_warning "This action cannot be undone!"
    echo
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "Aborted by user"
        exit 0
    fi
}

# Main function
main() {
    local argocd_only=false
    local crds_only=false
    local cluster_only=false
    local namespaces_only=false
    local skip_argocd=false
    local skip_crds=false
    local skip_cluster=false
    local skip_namespaces=false
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --argocd-only)
                argocd_only=true
                shift
                ;;
            --crds-only)
                crds_only=true
                shift
                ;;
            --cluster-only)
                cluster_only=true
                shift
                ;;
            --namespaces-only)
                namespaces_only=true
                shift
                ;;
            --skip-argocd)
                skip_argocd=true
                shift
                ;;
            --skip-crds)
                skip_crds=true
                shift
                ;;
            --skip-cluster)
                skip_cluster=true
                shift
                ;;
            --skip-namespaces)
                skip_namespaces=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_kubectl
    
    if [[ "$dry_run" == "true" ]]; then
        print_info "DRY RUN MODE - No resources will be deleted"
        print_info "This would delete all resources created by the Kyverno and Nirmata charts"
        return 0
    fi
    
    print_info "Starting cleanup of Kyverno and Nirmata resources..."
    print_info "Cluster: $(kubectl config current-context)"
    
    # Confirm deletion unless specific component is requested
    if [[ "$argocd_only" == "false" && "$crds_only" == "false" && "$cluster_only" == "false" && "$namespaces_only" == "false" ]]; then
        confirm_deletion
    fi
    
    echo
    
    # Execute deletion based on options
    if [[ "$argocd_only" == "true" ]]; then
        delete_argocd_apps
    elif [[ "$crds_only" == "true" ]]; then
        delete_crds_and_resources
    elif [[ "$cluster_only" == "true" ]]; then
        delete_cluster_resources
    elif [[ "$namespaces_only" == "true" ]]; then
        delete_namespaced_resources
        delete_namespaces
    else
        # Delete everything in order
        if [[ "$skip_argocd" == "false" ]]; then
            delete_argocd_apps
        fi
        
        if [[ "$skip_crds" == "false" ]]; then
            delete_crds_and_resources
        fi
        
        if [[ "$skip_cluster" == "false" ]]; then
            delete_cluster_resources
        fi
        
        if [[ "$skip_namespaces" == "false" ]]; then
            delete_namespaced_resources
            delete_namespaces
        fi
    fi
    
    echo
    print_info "Cleanup completed!"
    echo
    print_info "You may want to verify that all resources have been deleted:"
    echo "  kubectl get all --all-namespaces | grep -E '(kyverno|nirmata)'"
    echo "  kubectl get crd | grep -E '(kyverno|nirmata)'"
    echo "  kubectl get clusterroles | grep -E '(kyverno|nirmata)'"
    echo "  kubectl get clusterrolebindings | grep -E '(kyverno|nirmata)'"
    echo "  kubectl get applications -n argocd"
}

# Run main function
main "$@" 