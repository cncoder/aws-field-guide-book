#!/bin/bash

# MSK PoC Deployment Script
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

# Check if AWS CLI is configured
check_aws_config() {
    print_status "Checking AWS CLI configuration..."
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        print_error "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    print_success "AWS CLI is configured"
}

# Check if Terraform is installed
check_terraform() {
    print_status "Checking Terraform installation..."
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    print_success "Terraform is installed: $(terraform version | head -n1)"
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    cd terraform
    terraform init
    print_success "Terraform initialized"
}

# Plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    print_success "Terraform plan completed"
}

# Apply Terraform deployment
apply_terraform() {
    print_status "Applying Terraform deployment..."
    print_warning "This will create AWS resources that may incur costs"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
        print_success "Terraform deployment completed"
    else
        print_warning "Deployment cancelled"
        exit 0
    fi
}

# Get Terraform outputs and generate configuration
get_outputs() {
    print_status "Generating configuration from Terraform outputs..."
    cd ..
    
    # Use the automatic configuration generation script
    ./scripts/generate_config.sh
    
    print_success "Configuration generated successfully"
    
    # Display key information
    echo
    print_status "Deployment Summary:"
    source msk_config.env
    echo "MSK Cluster ARN: $MSK_CLUSTER_ARN"
    echo "EC2 Instance ID: $EC2_INSTANCE_ID"
    echo "Bootstrap Servers (IAM): $MSK_BOOTSTRAP_SERVERS_IAM"
    echo "Bootstrap Servers (SCRAM): $MSK_BOOTSTRAP_SERVERS_SCRAM"
    
    cd terraform
}

# Wait for MSK cluster to be ready
wait_for_msk() {
    print_status "Waiting for MSK cluster to be ready..."
    local cluster_arn=$(terraform output -raw msk_cluster_arn)
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local state=$(aws kafka describe-cluster --cluster-arn "$cluster_arn" --region ap-southeast-1 --query 'ClusterInfo.State' --output text)
        
        if [ "$state" = "ACTIVE" ]; then
            print_success "MSK cluster is active"
            return 0
        fi
        
        print_status "MSK cluster state: $state (attempt $attempt/$max_attempts)"
        sleep 30
        ((attempt++))
    done
    
    print_error "MSK cluster did not become active within expected time"
    return 1
}

# Copy Python scripts to EC2
copy_scripts() {
    print_status "Copying Python scripts to EC2 instance..."
    local instance_id=$(terraform output -raw ec2_instance_id)
    
    # Create temporary directory for scripts
    local temp_dir=$(mktemp -d)
    cp -r ../python-clients/* "$temp_dir/"
    
    # Copy scripts using SSM
    aws ssm send-command \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunShellScript" \
        --region ap-southeast-1 \
        --parameters 'commands=["mkdir -p /home/ec2-user/msk-poc"]' \
        --output text > /dev/null
    
    # Wait a moment for directory creation
    sleep 5
    
    # Copy each Python file
    for script in "$temp_dir"/*.py; do
        local script_name=$(basename "$script")
        local script_content=$(cat "$script")
        
        aws ssm send-command \
            --instance-ids "$instance_id" \
            --document-name "AWS-RunShellScript" \
            --region ap-southeast-1 \
            --parameters "commands=[\"cat > /home/ec2-user/msk-poc/$script_name << 'EOF'
$script_content
EOF\", \"chmod +x /home/ec2-user/msk-poc/$script_name\", \"chown ec2-user:ec2-user /home/ec2-user/msk-poc/$script_name\"]" \
            --output text > /dev/null
    done
    
    # Clean up
    rm -rf "$temp_dir"
    
    print_success "Python scripts copied to EC2 instance"
}

# Main deployment function
main() {
    print_status "Starting MSK PoC deployment..."
    
    # Pre-flight checks
    check_aws_config
    check_terraform
    
    # Terraform deployment
    init_terraform
    plan_terraform
    apply_terraform
    get_outputs
    
    # Wait for resources to be ready
    wait_for_msk
    
    # Copy scripts
    copy_scripts
    
    cd ..
    
    print_success "Deployment completed successfully!"
    echo
    print_status "Configuration file generated: msk_config.env"
    print_status "Next steps:"
    echo "1. Verify configuration: ./verify_config.sh"
    echo "2. Source the configuration: source msk_config.env"
    echo "3. Run the test script: ./scripts/test.sh"
    echo "4. Or connect to EC2 instance manually:"
    echo "   aws ssm start-session --target \$EC2_INSTANCE_ID --region ap-southeast-1"
}

# Run main function
main "$@"
