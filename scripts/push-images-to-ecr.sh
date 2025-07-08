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

# Check if required environment variables are set
if [[ -z "${AWS_REGION:-}" ]]; then
    print_error "AWS_REGION environment variable is not set"
    exit 1
fi

if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
    print_error "AWS_ACCOUNT_ID environment variable is not set"
    exit 1
fi

# Set default values
ECR_REPO_PREFIX="${ECR_REPO_PREFIX:-nirmata}"
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

print_info "Pushing images to ECR registry: $ECR_REGISTRY"
print_info "ECR Repository Prefix: $ECR_REPO_PREFIX"

# Array of images with their source and destination information
declare -A images=(
    # Public images from ghcr.io
    ["ghcr.io/nirmata/nirmata-kube-controller:v3.10.9"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/nirmata-kube-controller:v3.10.9"
    ["ghcr.io/nirmata/opentelemetry-collector:0.92.0"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/opentelemetry-collector:0.92.0"
    ["ghcr.io/nirmata/nirmata-kyverno-operator:v0.4.7"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/nirmata-kyverno-operator:v0.4.7"
    ["ghcr.io/nirmata/etcd:v3.5.18-cve-free"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/etcd:v3.5.18-cve-free"
    ["ghcr.io/nirmata/kubectl:1.30.2"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/kubectl:1.30.2"
    
    # Private images from reg.nirmata.io
    ["reg.nirmata.io/nirmata/kyverno:v1.13.6-n4k.nirmata.1"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/kyverno:v1.13.6-n4k.nirmata.1"
    ["reg.nirmata.io/nirmata/kyvernopre:v1.13.6-n4k.nirmata.1"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/kyvernopre:v1.13.6-n4k.nirmata.1"
    ["reg.nirmata.io/nirmata/background-controller:v1.13.6-n4k.nirmata.1"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/background-controller:v1.13.6-n4k.nirmata.1"
    ["reg.nirmata.io/nirmata/cleanup-controller:v1.13.6-n4k.nirmata.1"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/cleanup-controller:v1.13.6-n4k.nirmata.1"
    ["reg.nirmata.io/nirmata/reports-controller:v1.13.6-n4k.nirmata.1"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/reports-controller:v1.13.6-n4k.nirmata.1"
    ["reg.nirmata.io/nirmata/reports-server:v0.1.19"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/reports-server:v0.1.19"
    ["reg.nirmata.io/nirmata/kyverno-cli:v1.13.6-n4k.nirmata.1"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/kyverno-cli:v1.13.6-n4k.nirmata.1"
    ["reg.nirmata.io/nirmata/kubectl:1.31.1"]="$ECR_REGISTRY/$ECR_REPO_PREFIX/kubectl:1.31.1"
)

# Function to authenticate with ECR
authenticate_ecr() {
    print_step "Authenticating Docker with ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
    print_info "Successfully authenticated with ECR"
}

# Function to authenticate with Nirmata registry
authenticate_nirmata() {
    if [[ -n "${NIRMATA_REGISTRY_USERNAME:-}" ]] && [[ -n "${NIRMATA_REGISTRY_PASSWORD:-}" ]]; then
        print_step "Authenticating with Nirmata private registry..."
        echo "$NIRMATA_REGISTRY_PASSWORD" | docker login --username "$NIRMATA_REGISTRY_USERNAME" --password-stdin reg.nirmata.io
        print_info "Successfully authenticated with Nirmata registry"
    else
        print_warning "Nirmata registry credentials not provided. You may need to authenticate manually for private images."
        print_warning "Set NIRMATA_REGISTRY_USERNAME and NIRMATA_REGISTRY_PASSWORD environment variables"
    fi
}

# Function to pull, tag, and push an image
process_image() {
    local source_image="$1"
    local target_image="$2"
    
    print_step "Processing image: $source_image"
    
    # Pull the source image
    print_info "Pulling image: $source_image"
    if ! docker pull "$source_image"; then
        print_error "Failed to pull image: $source_image"
        return 1
    fi
    
    # Tag the image for ECR
    print_info "Tagging image: $source_image -> $target_image"
    if ! docker tag "$source_image" "$target_image"; then
        print_error "Failed to tag image: $source_image"
        return 1
    fi
    
    # Push to ECR
    print_info "Pushing image: $target_image"
    if ! docker push "$target_image"; then
        print_error "Failed to push image: $target_image"
        return 1
    fi
    
    print_info "Successfully processed: $source_image"
    echo "---"
}

# Main execution
main() {
    local failed_images=()
    local successful_images=()
    
    print_info "Starting image migration to ECR..."
    echo
    
    # Authenticate with registries
    authenticate_ecr
    authenticate_nirmata
    echo
    
    # Process each image
    for source_image in "${!images[@]}"; do
        target_image="${images[$source_image]}"
        
        if process_image "$source_image" "$target_image"; then
            successful_images+=("$source_image")
        else
            failed_images+=("$source_image")
        fi
    done
    
    # Summary
    echo
    print_info "Migration Summary:"
    print_info "Successfully migrated: ${#successful_images[@]} images"
    if [[ ${#failed_images[@]} -gt 0 ]]; then
        print_warning "Failed to migrate: ${#failed_images[@]} images"
        echo
        print_error "Failed images:"
        for failed_image in "${failed_images[@]}"; do
            echo "  - $failed_image"
        done
        exit 1
    else
        print_info "All images migrated successfully!"
    fi
    
    echo
    print_info "Your ECR repository URLs:"
    for source_image in "${!images[@]}"; do
        target_image="${images[$source_image]}"
        echo "  $target_image"
    done
    
    echo
    print_info "Next steps:"
    echo "1. Update your Helm values files to use the ECR image URLs above"
    echo "2. Deploy applications with './scripts/deploy-apps.sh'"
}

# Run main function
main "$@" 