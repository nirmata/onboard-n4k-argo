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
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    print_warning "ArgoCD namespace not found. Please ensure ArgoCD is installed."
    print_info "You can install ArgoCD using:"
    echo "  kubectl create namespace argocd"
    echo "  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    exit 1
fi

# Array of ArgoCD application files
declare -a app_files=(
    "argocd/kyverno-app.yaml"
    "argocd/nirmata-kyverno-operator-app.yaml"
    "argocd/nirmata-kube-controller-app.yaml"
)

# Function to apply an ArgoCD application
deploy_app() {
    local app_file="$1"
    local app_name
    
    if [[ ! -f "$app_file" ]]; then
        print_error "Application file not found: $app_file"
        return 1
    fi
    
    app_name=$(basename "$app_file" .yaml | sed 's/-app$//')
    
    print_step "Deploying ArgoCD application: $app_name"
    
    # Apply the application manifest
    if kubectl apply -f "$app_file"; then
        print_info "Successfully applied: $app_file"
    else
        print_error "Failed to apply: $app_file"
        return 1
    fi
    
    # Wait for the application to be created
    print_info "Waiting for application to be recognized by ArgoCD..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if kubectl get application "$app_name" -n argocd &> /dev/null; then
            print_info "Application $app_name is now managed by ArgoCD"
            break
        fi
        sleep 2
        ((retries--))
    done
    
    if [[ $retries -eq 0 ]]; then
        print_warning "Timeout waiting for application $app_name to be recognized"
    fi
}

# Function to check application status
check_app_status() {
    local app_name="$1"
    print_info "Checking status of application: $app_name"
    
    if kubectl get application "$app_name" -n argocd &> /dev/null; then
        local health status sync
        health=$(kubectl get application "$app_name" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        status=$(kubectl get application "$app_name" -n argocd -o jsonpath='{.status.operationState.phase}' 2>/dev/null || echo "Unknown")
        sync=$(kubectl get application "$app_name" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        
        echo "  Health: $health"
        echo "  Sync: $sync"
        echo "  Operation: $status"
    else
        print_warning "Application $app_name not found"
    fi
}

# Main execution
main() {
    local failed_deployments=()
    local successful_deployments=()
    
    print_info "Starting ArgoCD application deployment..."
    print_info "Cluster: $(kubectl config current-context)"
    echo
    
    # Deploy each application
    for app_file in "${app_files[@]}"; do
        app_name=$(basename "$app_file" .yaml | sed 's/-app$//')
        
        if deploy_app "$app_file"; then
            successful_deployments+=("$app_name")
        else
            failed_deployments+=("$app_name")
        fi
        echo "---"
    done
    
    # Summary
    echo
    print_info "Deployment Summary:"
    print_info "Successfully deployed: ${#successful_deployments[@]} applications"
    
    if [[ ${#failed_deployments[@]} -gt 0 ]]; then
        print_warning "Failed to deploy: ${#failed_deployments[@]} applications"
        echo
        print_error "Failed applications:"
        for failed_app in "${failed_deployments[@]}"; do
            echo "  - $failed_app"
        done
    fi
    
    echo
    print_info "Application Status:"
    for app_name in "${successful_deployments[@]}"; do
        check_app_status "$app_name"
        echo
    done
    
    echo
    print_info "Next steps:"
    echo "1. Monitor application sync status:"
    echo "   kubectl get applications -n argocd"
    echo
    echo "2. Access ArgoCD UI to view application details:"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   Then open: https://localhost:8080"
    echo
    echo "3. Get ArgoCD admin password:"
    echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo
    echo "4. Sync applications manually if needed:"
    echo "   kubectl patch application kyverno -n argocd --type='merge' -p='{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{}}}'"
    
    if [[ ${#failed_deployments[@]} -gt 0 ]]; then
        exit 1
    fi
}

# Run main function
main "$@" 