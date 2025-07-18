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
    
    local apps=("nirmata-kube-controller" "kyverno-operator")
    
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
    kubectl delete admissionreports --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clusteradmissionreports --all --ignore-not-found=true --timeout=60s || true
    kubectl delete backgroundscanreports --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clusterbackgroundscanreports --all --ignore-not-found=true --timeout=60s || true
    kubectl delete policyreports --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clusterpolicyreports --all --ignore-not-found=true --timeout=60s || true
    
    # Delete Nirmata custom resources
    print_info "Deleting Nirmata custom resources..."
    kubectl delete kyvernoconfigs --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete policysets --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete kyvernoadapters --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete kyvernooperators --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    
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
        "admissionreports.kyverno.io"
        "clusteradmissionreports.kyverno.io"
        "backgroundscanreports.kyverno.io"
        "clusterbackgroundscanreports.kyverno.io"
        "policyreports.wgpolicyk8s.io"
        "clusterpolicyreports.wgpolicyk8s.io"
        "kyvernoconfigs.security.nirmata.io"
        "policysets.security.nirmata.io"
        "kyvernoadapters.security.nirmata.io"
        "kyvernooperators.security.nirmata.io"
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
    
    # Delete specific webhook configurations by name
    local webhook_configs=(
        "kyverno-cleanup-validating-webhook-cfg"
        "kyverno-exception-validating-webhook-cfg"
        "kyverno-global-context-validating-webhook-cfg"
        "kyverno-policy-validating-webhook-cfg"
        "kyverno-resource-validating-webhook-cfg"
        "kyverno-ttl-validating-webhook-cfg"
    )
    
    local mutating_webhook_configs=(
        "kyverno-policy-mutating-webhook-cfg"
        "kyverno-resource-mutating-webhook-cfg"
        "kyverno-verify-mutating-webhook-cfg"
    )
    
    for webhook in "${webhook_configs[@]}"; do
        print_info "Deleting validatingwebhookconfiguration/$webhook"
        # Remove finalizers first
        kubectl patch validatingwebhookconfiguration "$webhook" --type='merge' -p='{"metadata":{"finalizers":[]}}' &>/dev/null || true
        # Then delete
        kubectl delete validatingwebhookconfiguration "$webhook" --ignore-not-found=true --timeout=60s || true
    done
    
    for webhook in "${mutating_webhook_configs[@]}"; do
        print_info "Deleting mutatingwebhookconfiguration/$webhook"
        # Remove finalizers first
        kubectl patch mutatingwebhookconfiguration "$webhook" --type='merge' -p='{"metadata":{"finalizers":[]}}' &>/dev/null || true
        # Then delete
        kubectl delete mutatingwebhookconfiguration "$webhook" --ignore-not-found=true --timeout=60s || true
    done
    
    # Clean up any remaining kyverno webhook configurations with finalizer removal
    print_info "Cleaning up any remaining Kyverno webhook configurations..."
    
    # Get remaining validating webhooks and remove them
    kubectl get validatingwebhookconfigurations -o name 2>/dev/null | grep kyverno | while read -r webhook; do
        webhook_name=$(echo "$webhook" | cut -d'/' -f2)
        print_info "Removing finalizers and deleting $webhook"
        kubectl patch validatingwebhookconfiguration "$webhook_name" --type='merge' -p='{"metadata":{"finalizers":[]}}' &>/dev/null || true
        kubectl delete validatingwebhookconfiguration "$webhook_name" --ignore-not-found=true --timeout=60s || true
    done
    
    # Get remaining mutating webhooks and remove them
    kubectl get mutatingwebhookconfigurations -o name 2>/dev/null | grep kyverno | while read -r webhook; do
        webhook_name=$(echo "$webhook" | cut -d'/' -f2)
        print_info "Removing finalizers and deleting $webhook"
        kubectl patch mutatingwebhookconfiguration "$webhook_name" --type='merge' -p='{"metadata":{"finalizers":[]}}' &>/dev/null || true
        kubectl delete mutatingwebhookconfiguration "$webhook_name" --ignore-not-found=true --timeout=60s || true
    done
    
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
        "kyverno:admin:policies"
        "kyverno:admin:policyexceptions"
        "kyverno:admin:policyreports"
        "kyverno:admin:reports"
        "kyverno:view:policies"
        "kyverno:view:policyexceptions"
        "kyverno:view:policyreports"
        "kyverno:view:reports"
        "kyverno:rbac:admin:policies"
        "kyverno:rbac:admin:policyreports"
        "kyverno:rbac:admin:reports"
        "kyverno:rbac:admin:updaterequests"
        "kyverno:rbac:view:policies"
        "kyverno:rbac:view:policyreports"
        "kyverno:rbac:view:reports"
        "kyverno:rbac:view:updaterequests"
        "kyverno-cleanup-jobs"
        "kyverno-operator"
        "nirmata-kyverno-operator"
        "nirmata:readonly"
        "nirmata:controller"
        "nirmata:view"
    )
    
    for role in "${cluster_roles[@]}"; do
        safe_delete "clusterrole" "$role"
        safe_delete "clusterrolebinding" "$role"
    done
    
    # Delete specific cluster role bindings
    safe_delete "clusterrolebinding" "nirmata:readonly"
    safe_delete "clusterrolebinding" "nirmata:view"
    safe_delete "clusterrolebinding" "nirmata:controller"
    
    # Clean up any remaining kyverno/nirmata cluster roles and bindings
    print_info "Cleaning up any remaining Kyverno/Nirmata cluster resources..."
    kubectl get clusterroles -o name | grep -E '(kyverno|nirmata)' | xargs -r kubectl delete --ignore-not-found=true --timeout=60s || true
    kubectl get clusterrolebindings -o name | grep -E '(kyverno|nirmata)' | xargs -r kubectl delete --ignore-not-found=true --timeout=60s || true
}

# Function to delete namespaced resources
delete_namespaced_resources() {
    print_step "Deleting namespaced resources..."
    
    local namespaces=("kyverno" "nirmata-system" "nirmata")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            print_info "Deleting resources in namespace: $ns"
            
            # Delete all applications first
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
            
            # Delete horizontal pod autoscalers
            kubectl delete hpa --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            
            # Delete certificates and issuers (cert-manager)
            kubectl delete certificates --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            kubectl delete issuers --all -n "$ns" --ignore-not-found=true --timeout=60s || true
            
        else
            print_warning "Namespace $ns not found"
        fi
    done
}

# Function to force cleanup any remaining kyverno/nirmata resources
force_cleanup_remaining() {
    print_step "Force cleaning up any remaining Kyverno/Nirmata resources..."
    
    print_info "Searching for and deleting any remaining cluster-level resources..."
    
    # Clean up any remaining cluster roles and bindings
    kubectl get clusterroles -o name 2>/dev/null | grep -E '(kyverno|nirmata)' | while read -r resource; do
        print_info "Force deleting $resource"
        kubectl delete "$resource" --ignore-not-found=true --timeout=60s || true
    done
    
    kubectl get clusterrolebindings -o name 2>/dev/null | grep -E '(kyverno|nirmata)' | while read -r resource; do
        print_info "Force deleting $resource"
        kubectl delete "$resource" --ignore-not-found=true --timeout=60s || true
    done
    
    # Clean up any remaining webhook configurations
    kubectl get validatingwebhookconfigurations -o name 2>/dev/null | grep kyverno | while read -r resource; do
        print_info "Force deleting $resource"
        kubectl delete "$resource" --ignore-not-found=true --timeout=60s || true
    done
    
    kubectl get mutatingwebhookconfigurations -o name 2>/dev/null | grep kyverno | while read -r resource; do
        print_info "Force deleting $resource"
        kubectl delete "$resource" --ignore-not-found=true --timeout=60s || true
    done
    
    # Clean up any remaining CRDs
    kubectl get crd -o name 2>/dev/null | grep -E '(kyverno|nirmata)' | while read -r resource; do
        print_info "Force deleting $resource"
        kubectl delete "$resource" --ignore-not-found=true --timeout=60s || true
    done
    
    # Clean up any remaining APIServices
    kubectl get apiservices -o name 2>/dev/null | grep -E '(kyverno|wgpolicyk8s)' | while read -r resource; do
        print_info "Force deleting $resource"
        kubectl delete "$resource" --ignore-not-found=true --timeout=60s || true
    done
    
    print_info "Force cleanup completed"
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
    echo "Delete all resources created by the Nirmata Kube Controller and Kyverno Operator."
    echo
    echo "Options:"
    echo "  --argocd-only      Delete only ArgoCD applications"
    echo "  --crds-only        Delete only CRDs and their resources"
    echo "  --cluster-only     Delete only cluster-level resources"
    echo "  --namespaces-only  Delete only namespaced resources"
    echo "  --force-cleanup    Force cleanup any remaining kyverno/nirmata resources"
    echo "  --skip-argocd      Skip deleting ArgoCD applications"
    echo "  --skip-crds        Skip deleting CRDs"
    echo "  --skip-cluster     Skip deleting cluster-level resources"
    echo "  --skip-namespaces  Skip deleting namespaces"
    echo "  --dry-run          Show what would be deleted without actually deleting"
    echo "  --force            Skip confirmation prompts"
    echo "  -h, --help         Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Delete everything"
    echo "  $0 --argocd-only      # Delete only ArgoCD applications"
    echo "  $0 --skip-argocd      # Delete everything except ArgoCD applications"
    echo "  $0 --force-cleanup    # Force cleanup any remaining resources"
    echo "  $0 --force            # Delete everything without confirmation"
    echo "  $0 --dry-run          # Show what would be deleted"
}

# Function to confirm deletion
confirm_deletion() {
    if [[ "${FORCE:-false}" == "true" ]]; then
        return 0
    fi
    
    echo
    print_warning "This will delete ALL resources created by the Nirmata Kube Controller and Kyverno Operator."
    print_warning "This includes:"
    echo "  - ArgoCD applications (nirmata-kube-controller, kyverno-operator)"
    echo "  - All Kyverno policies and configurations"
    echo "  - All CRDs and their resources"
    echo "  - All cluster-level resources (ClusterRoles, ClusterRoleBindings, etc.)"
    echo "  - APIServices (v1.reports.kyverno.io, v1alpha2.wgpolicyk8s.io)"
    echo "  - Webhook configurations"
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

# Function to show dry run
show_dry_run() {
    print_info "DRY RUN MODE - The following resources would be deleted:"
    echo
    echo "ArgoCD Applications:"
    echo "  - nirmata-kube-controller"
    echo "  - kyverno-operator"
    echo
    echo "Kyverno Resources:"
    echo "  - All policies, clusterpolicies, policyexceptions"
    echo "  - All policy reports and admission reports"
    echo "  - All Kyverno CRDs"
    echo
    echo "Nirmata Resources:"
    echo "  - All kyvernoconfigs, policysets, kyvernoadapters"
    echo "  - All Nirmata CRDs"
    echo
    echo "Cluster Resources:"
    echo "  - APIServices: v1.reports.kyverno.io, v1alpha2.wgpolicyk8s.io"
    echo "  - ValidatingWebhookConfigurations and MutatingWebhookConfigurations"
    echo "  - ClusterRoles and ClusterRoleBindings"
    echo "  - FlowSchemas and PriorityLevelConfigurations"
    echo
    echo "Namespaces and their contents:"
    echo "  - kyverno"
    echo "  - nirmata-system"
    echo "  - nirmata"
}

# Main function
main() {
    local argocd_only=false
    local crds_only=false
    local cluster_only=false
    local namespaces_only=false
    local force_cleanup_only=false
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
            --force-cleanup)
                force_cleanup_only=true
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
        show_dry_run
        return 0
    fi
    
    print_info "Starting cleanup of Nirmata Kube Controller and Kyverno Operator resources..."
    print_info "Cluster: $(kubectl config current-context)"
    
    # Confirm deletion unless specific component is requested
    if [[ "$argocd_only" == "false" && "$crds_only" == "false" && "$cluster_only" == "false" && "$namespaces_only" == "false" && "$force_cleanup_only" == "false" ]]; then
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
    elif [[ "$force_cleanup_only" == "true" ]]; then
        force_cleanup_remaining
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
    echo "  kubectl get apiservices | grep -E '(kyverno|wgpolicyk8s)'"
    echo "  kubectl get validatingwebhookconfigurations | grep kyverno"
    echo "  kubectl get mutatingwebhookconfigurations | grep kyverno"
    echo
}

# Run main function
main "$@" 