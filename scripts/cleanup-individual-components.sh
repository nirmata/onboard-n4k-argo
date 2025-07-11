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

# Function to delete Kyverno component
delete_kyverno() {
    print_step "Deleting Kyverno component..."
    
    # Delete ArgoCD application
    if kubectl get application kyverno -n argocd &> /dev/null; then
        print_info "Deleting ArgoCD application: kyverno"
        kubectl patch application kyverno -n argocd --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
        kubectl delete application kyverno -n argocd --timeout=60s || true
    fi
    
    # Delete Kyverno policy resources
    print_info "Deleting Kyverno policy resources..."
    kubectl delete clusterpolicies --all --ignore-not-found=true --timeout=60s || true
    kubectl delete policies --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete cleanuppolicies --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clustercleanuppolicies --all --ignore-not-found=true --timeout=60s || true
    kubectl delete policyexceptions --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete globalcontextentries --all --ignore-not-found=true --timeout=60s || true
    kubectl delete updaterequests --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    
    # Delete Kyverno webhook configurations
    kubectl delete validatingwebhookconfigurations -l app.kubernetes.io/part-of=kyverno --ignore-not-found=true --timeout=60s || true
    kubectl delete mutatingwebhookconfigurations -l app.kubernetes.io/part-of=kyverno --ignore-not-found=true --timeout=60s || true
    
    # Delete Kyverno cluster resources
    local kyverno_roles=(
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
    )
    
    for role in "${kyverno_roles[@]}"; do
        safe_delete "clusterrole" "$role"
        safe_delete "clusterrolebinding" "$role"
    done
    
    # Delete FlowSchemas and PriorityLevelConfigurations
    kubectl delete flowschemas -l app.kubernetes.io/part-of=kyverno --ignore-not-found=true --timeout=60s || true
    kubectl delete prioritylevelconfigurations -l app.kubernetes.io/part-of=kyverno --ignore-not-found=true --timeout=60s || true
    
    # Delete Kyverno CRDs
    local kyverno_crds=(
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
    )
    
    for crd in "${kyverno_crds[@]}"; do
        safe_delete "crd" "$crd"
    done
    
    # Delete resources in kyverno namespace (excluding reports-server if it exists)
    if kubectl get namespace kyverno &> /dev/null; then
        print_info "Deleting Kyverno resources in namespace: kyverno"
        
        # Get all resources but exclude reports-server related ones
        kubectl get all -n kyverno -o name | grep -v -E "(reports-server|etcd)" | xargs -r kubectl delete -n kyverno --ignore-not-found=true --timeout=60s || true
        
        # Delete other resource types
        kubectl delete secrets -l app.kubernetes.io/part-of=kyverno -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete configmaps -l app.kubernetes.io/part-of=kyverno -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete serviceaccounts -l app.kubernetes.io/part-of=kyverno -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete roles -l app.kubernetes.io/part-of=kyverno -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete rolebindings -l app.kubernetes.io/part-of=kyverno -n kyverno --ignore-not-found=true --timeout=60s || true
    fi
    
    print_info "Kyverno component deleted successfully!"
}

# Function to delete Nirmata Kyverno Operator component
delete_nirmata_kyverno_operator() {
    print_step "Deleting Nirmata Kyverno Operator component..."
    
    # Delete ArgoCD application
    if kubectl get application nirmata-kyverno-operator -n argocd &> /dev/null; then
        print_info "Deleting ArgoCD application: nirmata-kyverno-operator"
        kubectl patch application nirmata-kyverno-operator -n argocd --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
        kubectl delete application nirmata-kyverno-operator -n argocd --timeout=60s || true
    fi
    
    # Delete Nirmata custom resources
    print_info "Deleting Nirmata custom resources..."
    kubectl delete kyvernoconfigs --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete policysets --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    
    # Delete operator webhook configurations
    kubectl delete validatingwebhookconfigurations kyverno-operator-validating-webhook-configuration --ignore-not-found=true --timeout=60s || true
    
    # Delete operator cluster resources
    safe_delete "clusterrole" "nirmata-kyverno-operator"
    safe_delete "clusterrolebinding" "nirmata-kyverno-operator"
    
    # Delete Nirmata CRDs
    local nirmata_crds=(
        "kyvernoconfigs.security.nirmata.io"
        "policysets.security.nirmata.io"
    )
    
    for crd in "${nirmata_crds[@]}"; do
        safe_delete "crd" "$crd"
    done
    
    # Delete resources in nirmata-system namespace
    if kubectl get namespace nirmata-system &> /dev/null; then
        print_info "Deleting resources in namespace: nirmata-system"
        kubectl delete all --all -n nirmata-system --ignore-not-found=true --timeout=120s || true
        kubectl delete pvc --all -n nirmata-system --ignore-not-found=true --timeout=60s || true
        kubectl delete secrets --all -n nirmata-system --ignore-not-found=true --timeout=60s || true
        kubectl delete configmaps --all -n nirmata-system --ignore-not-found=true --timeout=60s || true
        kubectl delete serviceaccounts --all -n nirmata-system --ignore-not-found=true --timeout=60s || true
        kubectl delete roles --all -n nirmata-system --ignore-not-found=true --timeout=60s || true
        kubectl delete rolebindings --all -n nirmata-system --ignore-not-found=true --timeout=60s || true
        
        # Delete namespace
        kubectl patch namespace nirmata-system --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
        kubectl delete namespace nirmata-system --timeout=120s || true
    fi
    
    print_info "Nirmata Kyverno Operator component deleted successfully!"
}

# Function to delete Nirmata Kube Controller component
delete_nirmata_kube_controller() {
    print_step "Deleting Nirmata Kube Controller component..."
    
    # Delete ArgoCD application
    if kubectl get application nirmata-kube-controller -n argocd &> /dev/null; then
        print_info "Deleting ArgoCD application: nirmata-kube-controller"
        kubectl patch application nirmata-kube-controller -n argocd --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
        kubectl delete application nirmata-kube-controller -n argocd --timeout=60s || true
    fi
    
    # Delete Nirmata cluster resources
    local nirmata_roles=(
        "nirmata:readonly"
        "nirmata:policy-exceptions"
        "nirmata:policy-sets"
    )
    
    for role in "${nirmata_roles[@]}"; do
        safe_delete "clusterrole" "$role"
        safe_delete "clusterrolebinding" "$role"
    done
    
    # Delete additional cluster role bindings
    safe_delete "clusterrolebinding" "nirmata:readonly-binding"
    safe_delete "clusterrolebinding" "nirmata:policy-exceptions-binding"
    safe_delete "clusterrolebinding" "nirmata:policy-sets-binding"
    
    # Delete resources in nirmata namespace
    if kubectl get namespace nirmata &> /dev/null; then
        print_info "Deleting resources in namespace: nirmata"
        kubectl delete all --all -n nirmata --ignore-not-found=true --timeout=120s || true
        kubectl delete pvc --all -n nirmata --ignore-not-found=true --timeout=60s || true
        kubectl delete secrets --all -n nirmata --ignore-not-found=true --timeout=60s || true
        kubectl delete configmaps --all -n nirmata --ignore-not-found=true --timeout=60s || true
        kubectl delete serviceaccounts --all -n nirmata --ignore-not-found=true --timeout=60s || true
        kubectl delete roles --all -n nirmata --ignore-not-found=true --timeout=60s || true
        kubectl delete rolebindings --all -n nirmata --ignore-not-found=true --timeout=60s || true
        
        # Delete namespace
        kubectl patch namespace nirmata --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
        kubectl delete namespace nirmata --timeout=120s || true
    fi
    
    print_info "Nirmata Kube Controller component deleted successfully!"
}

# Function to delete Reports Server component
delete_reports_server() {
    print_step "Deleting Reports Server component..."
    
    # Delete ArgoCD application
    if kubectl get application reports-server -n argocd &> /dev/null; then
        print_info "Deleting ArgoCD application: reports-server"
        kubectl patch application reports-server -n argocd --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
        kubectl delete application reports-server -n argocd --timeout=60s || true
    fi
    
    # Delete report resources
    print_info "Deleting report resources..."
    kubectl delete ephemeralreports --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clusterephemeralreports --all --ignore-not-found=true --timeout=60s || true
    kubectl delete policyreports --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    kubectl delete clusterpolicyreports --all --ignore-not-found=true --timeout=60s || true
    
    # Delete APIServices
    safe_delete "apiservice" "v1.reports.kyverno.io"
    safe_delete "apiservice" "v1alpha2.wgpolicyk8s.io"
    
    # Delete reports-server cluster resources
    safe_delete "clusterrole" "reports-server"
    safe_delete "clusterrolebinding" "reports-server"
    
    # Delete reports-server resources in kyverno namespace
    if kubectl get namespace kyverno &> /dev/null; then
        print_info "Deleting Reports Server resources in namespace: kyverno"
        
        # Delete specific reports-server resources
        kubectl delete all -l app.kubernetes.io/name=reports-server -n kyverno --ignore-not-found=true --timeout=120s || true
        kubectl delete all -l app=etcd-reports-server -n kyverno --ignore-not-found=true --timeout=120s || true
        kubectl delete pvc -l app=etcd-reports-server -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete secrets -l app.kubernetes.io/name=reports-server -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete configmaps -l app.kubernetes.io/name=reports-server -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete serviceaccounts -l app.kubernetes.io/name=reports-server -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete roles -l app.kubernetes.io/name=reports-server -n kyverno --ignore-not-found=true --timeout=60s || true
        kubectl delete rolebindings -l app.kubernetes.io/name=reports-server -n kyverno --ignore-not-found=true --timeout=60s || true
        
        # Delete etcd statefulset and related resources
        kubectl delete statefulset etcd -n kyverno --ignore-not-found=true --timeout=120s || true
        kubectl delete service etcd -n kyverno --ignore-not-found=true --timeout=60s || true
    fi
    
    print_info "Reports Server component deleted successfully!"
}

# Function to show help
show_help() {
    echo "Usage: $0 <component> [OPTIONS]"
    echo
    echo "Delete individual components created by the Kyverno and Nirmata charts."
    echo
    echo "Components:"
    echo "  kyverno                  Delete Kyverno component"
    echo "  nirmata-kyverno-operator Delete Nirmata Kyverno Operator component"
    echo "  nirmata-kube-controller  Delete Nirmata Kube Controller component"
    echo "  reports-server           Delete Reports Server component"
    echo
    echo "Options:"
    echo "  --force                  Skip confirmation prompts"
    echo "  -h, --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0 kyverno               # Delete Kyverno component"
    echo "  $0 reports-server        # Delete Reports Server component"
    echo "  $0 kyverno --force       # Delete Kyverno component without confirmation"
}

# Function to confirm deletion
confirm_deletion() {
    local component="$1"
    
    if [[ "${FORCE:-false}" == "true" ]]; then
        return 0
    fi
    
    echo
    print_warning "This will delete the $component component and all its resources."
    
    case "$component" in
        kyverno)
            print_warning "This includes:"
            echo "  - ArgoCD application: kyverno"
            echo "  - All Kyverno policies and configurations"
            echo "  - Kyverno CRDs and their resources"
            echo "  - Kyverno cluster-level resources"
            echo "  - Kyverno resources in the kyverno namespace"
            ;;
        nirmata-kyverno-operator)
            print_warning "This includes:"
            echo "  - ArgoCD application: nirmata-kyverno-operator"
            echo "  - Nirmata custom resources (kyvernoconfigs, policysets)"
            echo "  - Nirmata CRDs"
            echo "  - Operator cluster-level resources"
            echo "  - Namespace: nirmata-system and all its resources"
            ;;
        nirmata-kube-controller)
            print_warning "This includes:"
            echo "  - ArgoCD application: nirmata-kube-controller"
            echo "  - Nirmata cluster-level resources"
            echo "  - Namespace: nirmata and all its resources"
            ;;
        reports-server)
            print_warning "This includes:"
            echo "  - ArgoCD application: reports-server"
            echo "  - All report resources"
            echo "  - APIServices for reports"
            echo "  - Reports Server resources in the kyverno namespace"
            echo "  - ETCD StatefulSet and related resources"
            ;;
    esac
    
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
    local component=""
    local force=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            kyverno|nirmata-kyverno-operator|nirmata-kube-controller|reports-server)
                component="$1"
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
    
    # Check if component is specified
    if [[ -z "$component" ]]; then
        print_error "Component not specified"
        show_help
        exit 1
    fi
    
    # Check prerequisites
    check_kubectl
    
    print_info "Starting cleanup of $component component..."
    print_info "Cluster: $(kubectl config current-context)"
    
    # Confirm deletion
    confirm_deletion "$component"
    
    echo
    
    # Execute deletion based on component
    case "$component" in
        kyverno)
            delete_kyverno
            ;;
        nirmata-kyverno-operator)
            delete_nirmata_kyverno_operator
            ;;
        nirmata-kube-controller)
            delete_nirmata_kube_controller
            ;;
        reports-server)
            delete_reports_server
            ;;
    esac
    
    echo
    print_info "Cleanup of $component completed!"
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