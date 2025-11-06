#!/bin/bash

# CI/CD Demo - AWS Resources Cleanup Script
# This script deletes all AWS resources created for the microservices demo

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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Confirm deletion
confirm_deletion() {
    echo -e "${RED}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║   WARNING: This will delete all AWS resources!           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo "This will delete:"
    echo "  - ECS Cluster and Services"
    echo "  - ECR Repositories (and all images)"
    echo "  - CloudWatch Log Groups"
    echo "  - Security Group"
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation

    if [ "$confirmation" != "yes" ]; then
        echo "Cleanup cancelled."
        exit 0
    fi
}

# Delete ECS Services
delete_ecs_services() {
    print_section "Deleting ECS Services"

    for service in "${SERVICES[@]}"; do
        SERVICE_NAME="${service}-service"
        print_info "Checking service: $SERVICE_NAME"

        # Check if service exists
        if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" --query 'services[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
            print_info "Scaling down $SERVICE_NAME to 0..."
            aws ecs update-service \
                --cluster "$CLUSTER_NAME" \
                --service "$SERVICE_NAME" \
                --desired-count 0 \
                --region "$AWS_REGION" \
                &> /dev/null

            print_info "Deleting service $SERVICE_NAME..."
            aws ecs delete-service \
                --cluster "$CLUSTER_NAME" \
                --service "$SERVICE_NAME" \
                --force \
                --region "$AWS_REGION" \
                &> /dev/null

            print_success "Deleted service: $SERVICE_NAME"
        else
            print_warning "Service $SERVICE_NAME not found, skipping..."
        fi
    done

    # Wait for services to be deleted
    print_info "Waiting for services to be deleted..."
    sleep 10
}

# Delete ECS Cluster
delete_ecs_cluster() {
    print_section "Deleting ECS Cluster"

    if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
        print_info "Deleting cluster: $CLUSTER_NAME"
        aws ecs delete-cluster \
            --cluster "$CLUSTER_NAME" \
            --region "$AWS_REGION" \
            &> /dev/null
        print_success "Deleted ECS cluster: $CLUSTER_NAME"
    else
        print_warning "Cluster not found, skipping..."
    fi
}

# Delete ECR Repositories
delete_ecr_repositories() {
    print_section "Deleting ECR Repositories"

    for service in "${SERVICES[@]}"; do
        if aws ecr describe-repositories --repository-names "$service" --region "$AWS_REGION" &> /dev/null; then
            print_info "Deleting repository: $service"
            aws ecr delete-repository \
                --repository-name "$service" \
                --region "$AWS_REGION" \
                --force \
                &> /dev/null
            print_success "Deleted ECR repository: $service"
        else
            print_warning "Repository $service not found, skipping..."
        fi
    done
}

# Delete CloudWatch Log Groups
delete_log_groups() {
    print_section "Deleting CloudWatch Log Groups"

    for service in "${SERVICES[@]}"; do
        LOG_GROUP="/ecs/$service"
        if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$AWS_REGION" --query 'logGroups[0]' --output text &> /dev/null; then
            print_info "Deleting log group: $LOG_GROUP"
            aws logs delete-log-group \
                --log-group-name "$LOG_GROUP" \
                --region "$AWS_REGION" \
                &> /dev/null
            print_success "Deleted log group: $LOG_GROUP"
        else
            print_warning "Log group $LOG_GROUP not found, skipping..."
        fi
    done
}

# Delete Security Group
delete_security_group() {
    print_section "Deleting Security Group"

    SG_NAME="microservices-sg"

    # Get VPC ID
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region "$AWS_REGION")

    if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
        SG_ID=$(aws ec2 describe-security-groups \
            --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
            --query 'SecurityGroups[0].GroupId' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null)

        if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
            print_info "Deleting security group: $SG_ID"
            aws ec2 delete-security-group \
                --group-id "$SG_ID" \
                --region "$AWS_REGION" \
                &> /dev/null || print_warning "Could not delete security group (may be in use)"
            print_success "Deleted security group: $SG_ID"
        else
            print_warning "Security group not found, skipping..."
        fi
    fi
}

# Print summary
print_summary() {
    print_section "Cleanup Complete"

    echo -e "${GREEN}All resources have been cleaned up!${NC}\n"

    echo "NOTE: The following were NOT deleted (manual cleanup if needed):"
    echo "  - IAM Role: ecsTaskExecutionRole"
    echo "  - VPC and Subnets (default VPC)"
    echo "  - Load Balancer (if created manually)"
    echo ""
    echo "To delete the IAM role manually:"
    echo "  aws iam detach-role-policy --role-name ecsTaskExecutionRole \\"
    echo "    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    echo "  aws iam delete-role --role-name ecsTaskExecutionRole"
}

# Main execution
main() {
    echo -e "${YELLOW}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║   Microservices CI/CD Demo - AWS Resources Cleanup       ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    confirm_deletion
    delete_ecs_services
    delete_ecs_cluster
    delete_ecr_repositories
    delete_log_groups
    delete_security_group
    print_summary
}

# Run main function
main
