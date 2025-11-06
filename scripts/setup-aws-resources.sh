#!/bin/bash

# CI/CD Demo - AWS Resources Setup Script
# This script creates all necessary AWS resources for the microservices demo

set -e

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="microservices-cluster"
SERVICES=("api-gateway" "user-service" "product-service" "order-service" "notification-service")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_section() {
    echo -e "\n${GREEN}===================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}===================================${NC}\n"
}

print_info() {
    echo -e "${YELLOW}➜${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    print_success "AWS CLI is installed"
}

# Check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure'"
        exit 1
    fi
    print_success "AWS credentials are configured"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_info "AWS Account ID: $ACCOUNT_ID"
}

# Create ECR repositories
create_ecr_repositories() {
    print_section "Creating ECR Repositories"

    for service in "${SERVICES[@]}"; do
        print_info "Creating repository for $service..."

        if aws ecr describe-repositories --repository-names "$service" --region "$AWS_REGION" &> /dev/null; then
            print_info "Repository $service already exists, skipping..."
        else
            aws ecr create-repository \
                --repository-name "$service" \
                --region "$AWS_REGION" \
                --image-scanning-configuration scanOnPush=true \
                --tags Key=Project,Value=microservices-demo \
                &> /dev/null
            print_success "Created ECR repository: $service"
        fi
    done
}

# Create ECS Cluster
create_ecs_cluster() {
    print_section "Creating ECS Cluster"

    if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
        print_info "Cluster $CLUSTER_NAME already exists, skipping..."
    else
        aws ecs create-cluster \
            --cluster-name "$CLUSTER_NAME" \
            --region "$AWS_REGION" \
            --tags key=Project,value=microservices-demo \
            &> /dev/null
        print_success "Created ECS cluster: $CLUSTER_NAME"
    fi
}

# Create CloudWatch Log Groups
create_log_groups() {
    print_section "Creating CloudWatch Log Groups"

    for service in "${SERVICES[@]}"; do
        LOG_GROUP="/ecs/$service"
        print_info "Creating log group for $service..."

        if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$AWS_REGION" --query 'logGroups[0]' --output text &> /dev/null; then
            print_info "Log group $LOG_GROUP already exists, skipping..."
        else
            aws logs create-log-group \
                --log-group-name "$LOG_GROUP" \
                --region "$AWS_REGION" \
                &> /dev/null
            print_success "Created log group: $LOG_GROUP"
        fi

        # Set retention policy (7 days)
        aws logs put-retention-policy \
            --log-group-name "$LOG_GROUP" \
            --retention-in-days 7 \
            --region "$AWS_REGION" \
            &> /dev/null
    done
}

# Create IAM Role for ECS Task Execution
create_ecs_task_execution_role() {
    print_section "Creating ECS Task Execution Role"

    ROLE_NAME="ecsTaskExecutionRole"

    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        print_info "Role $ROLE_NAME already exists, skipping..."
    else
        # Create trust policy
        cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

        # Create role
        aws iam create-role \
            --role-name "$ROLE_NAME" \
            --assume-role-policy-document file:///tmp/trust-policy.json \
            &> /dev/null

        # Attach managed policy
        aws iam attach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" \
            &> /dev/null

        print_success "Created IAM role: $ROLE_NAME"

        # Cleanup
        rm /tmp/trust-policy.json
    fi

    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    print_info "Role ARN: $ROLE_ARN"
}

# Get default VPC information
get_vpc_info() {
    print_section "Getting VPC Information"

    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region "$AWS_REGION")

    if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
        print_error "No default VPC found. Please create a VPC first."
        exit 1
    fi

    print_success "Using VPC: $VPC_ID"

    # Get subnets
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region "$AWS_REGION")
    SUBNET_ARRAY=($SUBNETS)

    if [ ${#SUBNET_ARRAY[@]} -lt 2 ]; then
        print_error "Need at least 2 subnets. Found: ${#SUBNET_ARRAY[@]}"
        exit 1
    fi

    SUBNET_1="${SUBNET_ARRAY[0]}"
    SUBNET_2="${SUBNET_ARRAY[1]}"

    print_success "Using Subnets: $SUBNET_1, $SUBNET_2"
}

# Create Security Group
create_security_group() {
    print_section "Creating Security Group"

    SG_NAME="microservices-sg"
    SG_DESC="Security group for microservices demo"

    # Check if security group exists
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)

    if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
        print_info "Security group already exists: $SG_ID"
    else
        SG_ID=$(aws ec2 create-security-group \
            --group-name "$SG_NAME" \
            --description "$SG_DESC" \
            --vpc-id "$VPC_ID" \
            --region "$AWS_REGION" \
            --query 'GroupId' \
            --output text)

        # Add ingress rules
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port 3000-3004 \
            --cidr 0.0.0.0/0 \
            --region "$AWS_REGION" \
            &> /dev/null

        print_success "Created security group: $SG_ID"
    fi
}

# Print summary
print_summary() {
    print_section "Setup Summary"

    echo -e "${GREEN}AWS Resources Created Successfully!${NC}\n"

    echo "Resource Details:"
    echo "  AWS Account ID: $ACCOUNT_ID"
    echo "  Region: $AWS_REGION"
    echo "  ECS Cluster: $CLUSTER_NAME"
    echo "  VPC: $VPC_ID"
    echo "  Subnets: $SUBNET_1, $SUBNET_2"
    echo "  Security Group: $SG_ID"
    echo "  Task Execution Role: $ROLE_ARN"
    echo ""
    echo "ECR Repositories:"
    for service in "${SERVICES[@]}"; do
        echo "  - $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$service"
    done

    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Add the following secrets to your GitHub repository:"
    echo "   - AWS_ACCESS_KEY_ID"
    echo "   - AWS_SECRET_ACCESS_KEY"
    echo "   - AWS_ACCOUNT_ID=$ACCOUNT_ID"
    echo "   - AWS_REGION=$AWS_REGION"
    echo "   - ECS_CLUSTER=$CLUSTER_NAME"
    echo "   - ECS_TASK_EXECUTION_ROLE_ARN=$ROLE_ARN"
    echo "   - SUBNET_1=$SUBNET_1"
    echo "   - SUBNET_2=$SUBNET_2"
    echo "   - SECURITY_GROUP=$SG_ID"
    echo ""
    echo "2. Update task definition files in aws/task-definitions/ with:"
    echo "   - Replace YOUR_ACCOUNT_ID with: $ACCOUNT_ID"
    echo "   - Replace execution role ARN with: $ROLE_ARN"
    echo ""
    echo "3. Create ECS services (see scripts/create-ecs-services.sh)"
    echo ""
    echo "4. Push code to trigger the CI/CD pipeline!"
}

# Main execution
main() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║   Microservices CI/CD Demo - AWS Resources Setup         ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_aws_cli
    check_aws_credentials
    create_ecr_repositories
    create_ecs_cluster
    create_log_groups
    create_ecs_task_execution_role
    get_vpc_info
    create_security_group
    print_summary
}

# Run main function
main
