# Quick Start Guide

Get the microservices CI/CD demo up and running in under 30 minutes!

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Docker installed and running
- [ ] Node.js 18+ installed
- [ ] GitHub account
- [ ] Git installed

## Step 1: Clone and Explore (2 minutes)

```bash
git clone <your-repo-url>
cd ci-cd-demo

# Explore the structure
tree -L 2
```

## Step 2: Test Locally (5 minutes)

### Option A: Test with Node.js

```bash
# Install dependencies for all services
for service in api-gateway user-service product-service order-service notification-service; do
  cd services/$service
  npm install
  cd ../..
done

# Start services in separate terminals
cd services/user-service && npm start           # Terminal 1
cd services/product-service && npm start        # Terminal 2
cd services/order-service && npm start          # Terminal 3
cd services/notification-service && npm start   # Terminal 4
cd services/api-gateway && npm start            # Terminal 5

# Test the API (in a new terminal)
curl http://localhost:3000/health
curl http://localhost:3000/api/users
```

### Option B: Test with Docker

```bash
# Make script executable
chmod +x scripts/local-test.sh

# Run all services
./scripts/local-test.sh

# Test the API
curl http://localhost:3000/health
curl http://localhost:3000/api/users

# Create a user
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'

# Create an order (triggers notification)
curl -X POST http://localhost:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId": "1", "productId": "1", "quantity": 2, "totalAmount": 1999.98}'

# Clean up
docker stop api-gateway user-service product-service order-service notification-service
docker rm api-gateway user-service product-service order-service notification-service
```

## Step 3: Set Up AWS Resources (10 minutes)

```bash
# Make script executable
chmod +x scripts/setup-aws-resources.sh

# Run setup script
./scripts/setup-aws-resources.sh
```

This script creates:
- 5 ECR repositories
- ECS cluster
- CloudWatch log groups
- IAM roles
- Security groups

**Save the output!** You'll need these values for GitHub Secrets.

## Step 4: Configure GitHub Secrets (5 minutes)

1. Go to your GitHub repository
2. Navigate to: **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Add the following secrets (use values from Step 3 output):

```
AWS_ACCESS_KEY_ID=<your-access-key>
AWS_SECRET_ACCESS_KEY=<your-secret-key>
AWS_ACCOUNT_ID=<your-account-id>
AWS_REGION=us-east-1
ECS_CLUSTER=microservices-cluster
ECS_TASK_EXECUTION_ROLE_ARN=<role-arn-from-script>
SUBNET_1=<subnet-id-from-script>
SUBNET_2=<subnet-id-from-script>
SECURITY_GROUP=<sg-id-from-script>
```

## Step 5: Update Task Definitions (3 minutes)

Update the task definition files with your AWS Account ID:

```bash
# Replace YOUR_ACCOUNT_ID in all task definition files
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# For macOS
sed -i '' "s/YOUR_ACCOUNT_ID/$ACCOUNT_ID/g" aws/task-definitions/*.json

# For Linux
sed -i "s/YOUR_ACCOUNT_ID/$ACCOUNT_ID/g" aws/task-definitions/*.json
```

Or manually edit these files:
- `aws/task-definitions/api-gateway.json`
- `aws/task-definitions/user-service.json`
- `aws/task-definitions/product-service.json`
- `aws/task-definitions/order-service.json`
- `aws/task-definitions/notification-service.json`

## Step 6: Register Task Definitions (3 minutes)

```bash
# Register all task definitions
for file in aws/task-definitions/*.json; do
  echo "Registering $(basename $file)..."
  aws ecs register-task-definition \
    --cli-input-json file://$file \
    --region us-east-1
done
```

## Step 7: Create ECS Services (5 minutes)

Create services for each microservice:

```bash
# Get values from setup script output
CLUSTER_NAME="microservices-cluster"
SUBNET_1="<your-subnet-1>"
SUBNET_2="<your-subnet-2>"
SECURITY_GROUP="<your-sg-id>"

# Create services
for service in api-gateway user-service product-service order-service notification-service; do
  echo "Creating service: $service"

  aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name ${service}-service \
    --task-definition $service \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1,$SUBNET_2],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
    --region us-east-1
done
```

## Step 8: Trigger the Pipeline (2 minutes)

```bash
# Make a change
echo "# CI/CD Demo" >> README.md

# Commit and push
git add .
git commit -m "Test CI/CD pipeline"
git push origin main
```

## Step 9: Monitor the Deployment (5 minutes)

### Watch GitHub Actions

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Watch the workflow execution
4. Check logs for each step

### Check AWS ECS

```bash
# Check services
aws ecs list-services --cluster microservices-cluster --region us-east-1

# Check tasks
aws ecs list-tasks --cluster microservices-cluster --region us-east-1

# Describe a service
aws ecs describe-services \
  --cluster microservices-cluster \
  --services api-gateway-service \
  --region us-east-1

# View logs
aws logs tail /ecs/api-gateway --follow --region us-east-1
```

### Get Service URL

```bash
# Get task details to find public IP
aws ecs list-tasks \
  --cluster microservices-cluster \
  --service-name api-gateway-service \
  --region us-east-1

# Get task details (replace TASK_ID)
aws ecs describe-tasks \
  --cluster microservices-cluster \
  --tasks <TASK_ID> \
  --region us-east-1 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text

# Get public IP from network interface
aws ec2 describe-network-interfaces \
  --network-interface-ids <ENI_ID> \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text
```

## Step 10: Test the Deployed Services (3 minutes)

```bash
# Use the public IP from Step 9
PUBLIC_IP="<your-api-gateway-public-ip>"

# Health check
curl http://$PUBLIC_IP:3000/health

# Get users
curl http://$PUBLIC_IP:3000/api/users

# Create a user
curl -X POST http://$PUBLIC_IP:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Production User", "email": "prod@example.com"}'

# Create an order
curl -X POST http://$PUBLIC_IP:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId": "1", "productId": "1", "quantity": 1, "totalAmount": 999.99}'

# Get orders
curl http://$PUBLIC_IP:3000/api/orders
```

## Success! 🎉

You now have a fully functional CI/CD pipeline!

## Next Steps

### Add an Application Load Balancer (Recommended)

1. Create ALB in AWS Console
2. Create target groups for each service
3. Configure listeners and routing
4. Update security groups
5. Use ALB DNS instead of public IPs

### Enable Auto-Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/microservices-cluster/api-gateway-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 5

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/microservices-cluster/api-gateway-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-target-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

### Add Monitoring and Alerts

1. Set up CloudWatch dashboards
2. Create CloudWatch alarms
3. Configure SNS for notifications
4. Set up X-Ray for distributed tracing

### Improve Security

1. Switch to OIDC for GitHub Actions
2. Use AWS Secrets Manager for sensitive data
3. Move services to private subnets
4. Enable VPC Flow Logs
5. Set up WAF on ALB

## Troubleshooting

### Pipeline Fails at ECR Push

```bash
# Check ECR repositories exist
aws ecr describe-repositories --region us-east-1

# Check GitHub Secrets are correct
# Verify AWS credentials have ECR permissions
```

### ECS Task Won't Start

```bash
# Check CloudWatch logs
aws logs tail /ecs/api-gateway --follow

# Check task execution role permissions
aws iam get-role --role-name ecsTaskExecutionRole

# Verify security group allows required ports
aws ec2 describe-security-groups --group-ids <sg-id>
```

### Can't Access Service

```bash
# Verify task is running
aws ecs list-tasks --cluster microservices-cluster --desired-status RUNNING

# Check task has public IP
aws ecs describe-tasks --cluster microservices-cluster --tasks <task-id>

# Verify security group allows inbound traffic
# Check if assignPublicIp is ENABLED
```

## Clean Up

When you're done testing:

```bash
# Make script executable
chmod +x scripts/cleanup-aws-resources.sh

# Run cleanup script
./scripts/cleanup-aws-resources.sh
```

This removes all AWS resources to avoid charges.

## Support

- Read the full [README.md](../README.md)
- Check the [Pipeline Documentation](PIPELINE.md)
- Review [GitHub Actions Logs](https://github.com/your-repo/actions)
- Check AWS CloudWatch Logs

## Estimated Costs

Running this demo (5 services, 24 hours):
- ECS Fargate: ~$3-5/day
- ECR Storage: ~$0.10/month
- CloudWatch Logs: ~$0.50/month
- Data Transfer: Varies

**Remember to clean up resources when done!**
