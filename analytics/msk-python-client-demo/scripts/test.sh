#!/bin/bash

# MSK PoC Test Script
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

# Load configuration
load_config() {
    if [ -f "msk_config.env" ]; then
        source msk_config.env
        print_success "Configuration loaded"
    else
        print_error "Configuration file msk_config.env not found"
        print_status "Please run ./scripts/deploy.sh first"
        exit 1
    fi
}

# Check if EC2 instance is ready
check_ec2_ready() {
    print_status "Checking EC2 instance status..."
    local state=$(aws ec2 describe-instances --instance-ids "$EC2_INSTANCE_ID" --region "$AWS_DEFAULT_REGION" --query 'Reservations[0].Instances[0].State.Name' --output text)
    
    if [ "$state" != "running" ]; then
        print_error "EC2 instance is not running (state: $state)"
        exit 1
    fi
    
    print_success "EC2 instance is running"
}

# Execute command on EC2 via SSM
execute_on_ec2() {
    local command="$1"
    local description="$2"
    
    print_status "$description"
    
    local command_id=$(aws ssm send-command \
        --instance-ids "$EC2_INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --region "$AWS_DEFAULT_REGION" \
        --parameters "commands=[\"$command\"]" \
        --query 'Command.CommandId' \
        --output text)
    
    # Wait for command to complete
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local status=$(aws ssm get-command-invocation \
            --command-id "$command_id" \
            --instance-id "$EC2_INSTANCE_ID" \
            --region "$AWS_DEFAULT_REGION" \
            --query 'Status' \
            --output text 2>/dev/null || echo "InProgress")
        
        if [ "$status" = "Success" ]; then
            # Get command output
            aws ssm get-command-invocation \
                --command-id "$command_id" \
                --instance-id "$EC2_INSTANCE_ID" \
                --region "$AWS_DEFAULT_REGION" \
                --query 'StandardOutputContent' \
                --output text
            return 0
        elif [ "$status" = "Failed" ]; then
            print_error "Command failed"
            aws ssm get-command-invocation \
                --command-id "$command_id" \
                --instance-id "$EC2_INSTANCE_ID" \
                --region "$AWS_DEFAULT_REGION" \
                --query 'StandardErrorContent' \
                --output text
            return 1
        fi
        
        sleep 2
        ((attempt++))
    done
    
    print_error "Command timed out"
    return 1
}

# Setup environment on EC2
setup_environment() {
    print_status "Setting up environment on EC2..."
    
    local setup_commands="
# Set environment variables
export AWS_DEFAULT_REGION='$AWS_DEFAULT_REGION'
export MSK_BOOTSTRAP_SERVERS_IAM='$MSK_BOOTSTRAP_SERVERS_IAM'
export MSK_BOOTSTRAP_SERVERS_SCRAM='$MSK_BOOTSTRAP_SERVERS_SCRAM'
export MSK_SCRAM_SECRET_NAME='$MSK_SCRAM_SECRET_NAME'

# Add to .bashrc for persistence
echo 'export AWS_DEFAULT_REGION=\"$AWS_DEFAULT_REGION\"' >> ~/.bashrc
echo 'export MSK_BOOTSTRAP_SERVERS_IAM=\"$MSK_BOOTSTRAP_SERVERS_IAM\"' >> ~/.bashrc
echo 'export MSK_BOOTSTRAP_SERVERS_SCRAM=\"$MSK_BOOTSTRAP_SERVERS_SCRAM\"' >> ~/.bashrc
echo 'export MSK_SCRAM_SECRET_NAME=\"$MSK_SCRAM_SECRET_NAME\"' >> ~/.bashrc

# Install additional Python packages if needed
pip3 install --user confluent-kafka boto3 requests

echo 'Environment setup completed'
"
    
    execute_on_ec2 "$setup_commands" "Setting up environment"
}

# Test IAM authentication
test_iam_auth() {
    print_status "Testing IAM authentication..."
    
    # Test producer
    print_status "Running IAM producer..."
    if execute_on_ec2 "cd /home/ec2-user/msk-poc && python3 producer_iam.py" "Running IAM producer"; then
        print_success "IAM producer test completed"
    else
        print_error "IAM producer test failed"
        return 1
    fi
    
    # Wait a moment before running consumer
    sleep 5
    
    # Test consumer
    print_status "Running IAM consumer..."
    if execute_on_ec2 "cd /home/ec2-user/msk-poc && timeout 60 python3 consumer_iam.py" "Running IAM consumer"; then
        print_success "IAM consumer test completed"
    else
        print_error "IAM consumer test failed"
        return 1
    fi
    
    print_success "IAM authentication tests completed successfully"
}

# Test SASL/SCRAM authentication
test_scram_auth() {
    print_status "Testing SASL/SCRAM authentication..."
    
    # Test producer
    print_status "Running SCRAM producer..."
    if execute_on_ec2 "cd /home/ec2-user/msk-poc && python3 producer_scram.py" "Running SCRAM producer"; then
        print_success "SCRAM producer test completed"
    else
        print_error "SCRAM producer test failed"
        return 1
    fi
    
    # Wait a moment before running consumer
    sleep 5
    
    # Test consumer
    print_status "Running SCRAM consumer..."
    if execute_on_ec2 "cd /home/ec2-user/msk-poc && timeout 60 python3 consumer_scram.py" "Running SCRAM consumer"; then
        print_success "SCRAM consumer test completed"
    else
        print_error "SCRAM consumer test failed"
        return 1
    fi
    
    print_success "SASL/SCRAM authentication tests completed successfully"
}

# Create topic using Kafka tools
create_topic() {
    print_status "Creating Kafka topic..."
    
    local create_topic_cmd="
export KAFKA_HOME=/opt/kafka/current
\$KAFKA_HOME/bin/kafka-topics.sh --create \
    --bootstrap-server '$MSK_BOOTSTRAP_SERVERS_TLS' \
    --replication-factor 2 \
    --partitions 3 \
    --topic msk-poc-topic \
    --command-config <(echo 'security.protocol=SSL') || echo 'Topic may already exist'
"
    
    execute_on_ec2 "$create_topic_cmd" "Creating topic"
}

# List topics
list_topics() {
    print_status "Listing Kafka topics..."
    
    local list_topics_cmd="
export KAFKA_HOME=/opt/kafka/current
\$KAFKA_HOME/bin/kafka-topics.sh --list \
    --bootstrap-server '$MSK_BOOTSTRAP_SERVERS_TLS' \
    --command-config <(echo 'security.protocol=SSL')
"
    
    execute_on_ec2 "$list_topics_cmd" "Listing topics"
}

# Show cluster information
show_cluster_info() {
    print_status "MSK Cluster Information:"
    echo "Cluster ARN: $MSK_CLUSTER_ARN"
    echo "Cluster Name: $MSK_CLUSTER_NAME"
    echo "Bootstrap Servers (IAM): $MSK_BOOTSTRAP_SERVERS_IAM"
    echo "Bootstrap Servers (SCRAM): $MSK_BOOTSTRAP_SERVERS_SCRAM"
    echo "Bootstrap Servers (TLS): $MSK_BOOTSTRAP_SERVERS_TLS"
    echo "EC2 Instance ID: $EC2_INSTANCE_ID"
    echo "EC2 Private IP: $EC2_PRIVATE_IP"
}

# Interactive session
start_interactive_session() {
    print_status "Starting interactive session with EC2 instance..."
    print_status "You can now run commands directly on the EC2 instance"
    print_status "Python scripts are located in: /home/ec2-user/msk-poc/"
    print_status "To exit the session, type 'exit'"
    
    aws ssm start-session --target "$EC2_INSTANCE_ID" --region "$AWS_DEFAULT_REGION"
}

# Main test function
main() {
    local test_type="${1:-all}"
    
    print_status "Starting MSK PoC tests..."
    
    # Load configuration
    load_config
    
    # Show cluster information
    show_cluster_info
    echo
    
    # Check EC2 instance
    check_ec2_ready
    
    # Setup environment
    setup_environment
    
    # Create topic
    create_topic
    
    # List topics
    list_topics
    
    case "$test_type" in
        "iam")
            test_iam_auth
            ;;
        "scram")
            test_scram_auth
            ;;
        "interactive")
            start_interactive_session
            ;;
        "all"|*)
            # Run both authentication tests
            test_iam_auth
            echo
            test_scram_auth
            ;;
    esac
    
    print_success "All tests completed successfully!"
    echo
    print_status "To run interactive session: ./scripts/test.sh interactive"
    print_status "To run specific tests: ./scripts/test.sh [iam|scram|all]"
}

# Show usage
usage() {
    echo "Usage: $0 [iam|scram|all|interactive]"
    echo "  iam         - Test IAM authentication only"
    echo "  scram       - Test SASL/SCRAM authentication only"
    echo "  all         - Test both authentication methods (default)"
    echo "  interactive - Start interactive session with EC2 instance"
}

# Handle command line arguments
case "${1:-}" in
    "-h"|"--help")
        usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
