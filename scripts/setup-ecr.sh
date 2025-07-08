#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

print_info "Setting up ECR repositories in region: $AWS_REGION"
print_info "AWS Account ID: $AWS_ACCOUNT_ID"
print_info "ECR Repository Prefix: $ECR_REPO_PREFIX"

# List of images that need ECR repositories
declare -a images=(
    "nirmata-kube-controller"
    "opentelemetry-collector"
    "nirmata-kyverno-operator"
    "etcd"
    "kyverno"
    "kyvernopre"
    "background-controller"
    "cleanup-controller"
    "reports-controller"
    "reports-server"
    "kyverno-cli"
    "kubectl"
)

# Function to create ECR repository
create_ecr_repo() {
    local repo_name="$1"
    local full_repo_name="$ECR_REPO_PREFIX/$repo_name"
    
    print_info "Creating ECR repository: $full_repo_name"
    
    if aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$full_repo_name" >/dev/null 2>&1; then
        print_warning "Repository $full_repo_name already exists, skipping..."
    else
        aws ecr create-repository \
            --region "$AWS_REGION" \
            --repository-name "$full_repo_name" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 >/dev/null
        
        print_info "Successfully created repository: $full_repo_name"
        
        # Set lifecycle policy to manage image retention
        aws ecr put-lifecycle-configuration \
            --region "$AWS_REGION" \
            --repository-name "$full_repo_name" \
            --lifecycle-policy-text '{
                "rules": [
                    {
                        "rulePriority": 1,
                        "description": "Keep last 10 images",
                        "selection": {
                            "tagStatus": "any",
                            "countType": "imageCountMoreThan",
                            "countNumber": 10
                        },
                        "action": {
                            "type": "expire"
                        }
                    }
                ]
            }' >/dev/null
        
        print_info "Set lifecycle policy for repository: $full_repo_name"
    fi
}

print_info "Starting ECR repository creation..."

# Create repositories for each image
for image in "${images[@]}"; do
    create_ecr_repo "$image"
done

print_info "ECR repository setup completed successfully!"

# Display the ECR registry URL
echo
print_info "Your ECR registry URL: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
print_info "Repository prefix: $ECR_REPO_PREFIX"

echo
print_info "Next steps:"
echo "1. Run './scripts/push-images-to-ecr.sh' to push container images to ECR"
echo "2. Update your Helm values files to use the ECR image URLs"
echo "3. Deploy applications with './scripts/deploy-apps.sh'" 