#!/bin/bash

# MSK PoC Cleanup Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Terraform state exists
check_terraform_state() {
    if [ ! -f "terraform/terraform.tfstate" ]; then
        print_warning "No Terraform state file found"
        print_status "Resources may have already been destroyed or were never created"
        return 1
    fi
    return 0
}

# Destroy Terraform resources
destroy_terraform() {
    print_status "Destroying Terraform resources..."
    print_warning "This will destroy all AWS resources created by this PoC"
    
    if [ "${1:-}" != "--force" ]; then
        read -p "Are you sure you want to destroy all resources? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Cleanup cancelled"
            exit 0
        fi
    fi
    
    cd terraform
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Destroy resources
    terraform destroy -auto-approve
    
    print_success "Terraform resources destroyed"
    cd ..
}

# Clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove configuration file
    if [ -f "msk_config.env" ]; then
        rm msk_config.env
        print_status "Removed msk_config.env"
    fi
    
    # Remove Terraform state files (optional)
    read -p "Do you want to remove Terraform state files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "terraform/terraform.tfstate" ]; then
            rm terraform/terraform.tfstate
            print_status "Removed terraform.tfstate"
        fi
        if [ -f "terraform/terraform.tfstate.backup" ]; then
            rm terraform/terraform.tfstate.backup
            print_status "Removed terraform.tfstate.backup"
        fi
        if [ -f "terraform/tfplan" ]; then
            rm terraform/tfplan
            print_status "Removed tfplan"
        fi
        if [ -d "terraform/.terraform" ]; then
            rm -rf terraform/.terraform
            print_status "Removed .terraform directory"
        fi
        if [ -f "terraform/.terraform.lock.hcl" ]; then
            rm terraform/.terraform.lock.hcl
            print_status "Removed .terraform.lock.hcl"
        fi
    fi
    
    print_success "Local cleanup completed"
}

# Show current resources (if state exists)
show_resources() {
    if check_terraform_state; then
        print_status "Current Terraform resources:"
        cd terraform
        terraform show -no-color | head -20
        echo "..."
        cd ..
    else
        print_status "No Terraform state found"
    fi
}

# Main cleanup function
main() {
    local action="${1:-interactive}"
    
    print_status "MSK PoC Cleanup"
    
    case "$action" in
        "--show"|"show")
            show_resources
            ;;
        "--force"|"force")
            if check_terraform_state; then
                destroy_terraform --force
                cleanup_local_files
            else
                print_status "No resources to destroy"
                cleanup_local_files
            fi
            ;;
        "--help"|"help")
            usage
            ;;
        *)
            # Interactive mode
            if check_terraform_state; then
                show_resources
                echo
                destroy_terraform
                cleanup_local_files
            else
                print_status "No Terraform resources found to destroy"
                cleanup_local_files
            fi
            ;;
    esac
    
    print_success "Cleanup completed!"
}

# Show usage
usage() {
    echo "Usage: $0 [show|force|help]"
    echo "  show  - Show current resources without destroying"
    echo "  force - Destroy resources without confirmation"
    echo "  help  - Show this help message"
    echo "  (no args) - Interactive cleanup with confirmation"
}

# Run main function
main "$@"
