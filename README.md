# CI/CD Pipeline Demo with Microservices

A complete demonstration of a CI/CD pipeline using GitHub Actions and AWS ECS/ECR, featuring 5 interconnected microservices.

## Architecture

This project demonstrates a microservices architecture with the following services:

1. **API Gateway** (Port 3000) - Entry point for all client requests
2. **User Service** (Port 3001) - Manages user operations
3. **Product Service** (Port 3002) - Handles product catalog
4. **Order Service** (Port 3003) - Processes orders
5. **Notification Service** (Port 3004) - Sends notifications

## Tech Stack

- **Application**: Node.js with Express
- **Containerization**: Docker
- **CI/CD**: GitHub Actions
- **Container Registry**: AWS ECR
- **Orchestration**: AWS ECS (Fargate)
- **Load Balancing**: AWS Application Load Balancer

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **GitHub Account** with this repository
3. **AWS CLI** installed and configured
4. **Docker** installed (for local testing)
5. **Node.js 18+** installed (for local development)

## AWS Setup

### 1. Create AWS Resources

You'll need to create the following AWS resources (can be done via AWS Console or CLI):

#### ECR Repositories

Create 5 ECR repositories, one for each service:

```bash
aws ecr create-repository --repository-name api-gateway --region us-east-1
aws ecr create-repository --repository-name user-service --region us-east-1
aws ecr create-repository --repository-name product-service --region us-east-1
aws ecr create-repository --repository-name order-service --region us-east-1
aws ecr create-repository --repository-name notification-service --region us-east-1
```

#### ECS Cluster

```bash
aws ecs create-cluster --cluster-name microservices-cluster --region us-east-1
```

#### VPC and Networking

You'll need:
- A VPC with at least 2 public subnets (or use default VPC)
- Security groups allowing traffic on ports 3000-3004
- An Application Load Balancer

#### IAM Role for ECS Task Execution

Create an ECS task execution role with the following policies:
- `AmazonECSTaskExecutionRolePolicy`
- Permissions to pull from ECR

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=your-account-id
ECS_CLUSTER=microservices-cluster
ECS_TASK_EXECUTION_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole
SUBNET_1=subnet-xxxxx
SUBNET_2=subnet-yyyyy
SECURITY_GROUP=sg-zzzzz
```

For CI/CD authentication, configure either:

**Option 1: OIDC (Recommended)**
- Set up GitHub OIDC provider in AWS IAM
- Configure the workflow to use OIDC authentication

**Option 2: IAM User Credentials**
```
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
```

### 3. Update Task Definitions

Update the files in `aws/task-definitions/` with your actual values:
- AWS Account ID
- Region
- Subnet IDs
- Security Group IDs
- Task execution role ARN

## Local Development

### Install Dependencies

```bash
# Install dependencies for all services
cd services/api-gateway && npm install && cd ../..
cd services/user-service && npm install && cd ../..
cd services/product-service && npm install && cd ../..
cd services/order-service && npm install && cd ../..
cd services/notification-service && npm install && cd ../..
```

### Run Services Locally

Each service can be run independently:

```bash
# Terminal 1 - User Service
cd services/user-service
npm start

# Terminal 2 - Product Service
cd services/product-service
npm start

# Terminal 3 - Order Service
cd services/order-service
npm start

# Terminal 4 - Notification Service
cd services/notification-service
npm start

# Terminal 5 - API Gateway
cd services/api-gateway
npm start
```

### Test Locally with Docker

Build and run all services with Docker:

```bash
# Build all images
docker build -t api-gateway ./services/api-gateway
docker build -t user-service ./services/user-service
docker build -t product-service ./services/product-service
docker build -t order-service ./services/order-service
docker build -t notification-service ./services/notification-service

# Run containers (adjust as needed)
docker run -d -p 3001:3001 user-service
docker run -d -p 3002:3002 product-service
docker run -d -p 3003:3003 order-service
docker run -d -p 3004:3004 notification-service
docker run -d -p 3000:3000 \
  -e USER_SERVICE_URL=http://localhost:3001 \
  -e PRODUCT_SERVICE_URL=http://localhost:3002 \
  -e ORDER_SERVICE_URL=http://localhost:3003 \
  -e NOTIFICATION_SERVICE_URL=http://localhost:3004 \
  api-gateway
```

## API Endpoints

### API Gateway (Port 3000)

**User Endpoints:**
- `GET /api/users` - List all users
- `GET /api/users/:id` - Get user by ID
- `POST /api/users` - Create user

**Product Endpoints:**
- `GET /api/products` - List all products
- `GET /api/products/:id` - Get product by ID
- `POST /api/products` - Create product

**Order Endpoints:**
- `GET /api/orders` - List all orders
- `GET /api/orders/:id` - Get order by ID
- `POST /api/orders` - Create order (triggers notification)

### Example Requests

```bash
# Create a user
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# Create a product
curl -X POST http://localhost:3000/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Laptop", "price": 999.99}'

# Create an order
curl -X POST http://localhost:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId": "1", "productId": "1", "quantity": 2}'

# Get all orders
curl http://localhost:3000/api/orders
```

## CI/CD Pipeline

The CI/CD pipeline is automated using GitHub Actions and triggers on push to the `main` branch or specified feature branches.

### Pipeline Stages

1. **Checkout Code** - Clones the repository
2. **Configure AWS Credentials** - Authenticates with AWS
3. **Login to Amazon ECR** - Authenticates Docker with ECR
4. **Build Docker Images** - Builds images for all 5 services
5. **Tag Images** - Tags images with commit SHA
6. **Push to ECR** - Pushes images to Amazon ECR
7. **Update ECS Task Definitions** - Updates task definitions with new image URIs
8. **Deploy to ECS** - Deploys services to ECS cluster

### Workflow Triggers

- Push to `main` branch
- Push to branches starting with `claude/`
- Manual trigger via workflow_dispatch

### Pipeline Flow Diagram

```
┌─────────────────┐
│  Code Commit    │
│  (GitHub)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GitHub Actions  │
│   Triggered     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Build Docker   │
│    Images       │
│  (5 services)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Push Images   │
│   to AWS ECR    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update ECS Task │
│   Definitions   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Deploy to ECS  │
│    (Fargate)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Services      │
│    Running      │
└─────────────────┘
```

### Monitoring Deployments

Monitor your deployment in the AWS Console:

1. **ECS Console**: Check service status and task health
2. **CloudWatch Logs**: View application logs
3. **ECR Console**: Verify image pushes
4. **GitHub Actions**: Monitor workflow execution

## Deployment Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      Internet                                 │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │  Application Load     │
                │      Balancer         │
                └───────────┬───────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │    API Gateway        │
                │  (ECS Fargate Task)   │
                └───────────┬───────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│    User      │    │   Product    │    │    Order     │
│   Service    │    │   Service    │    │   Service    │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                                │
                                                ▼
                                        ┌──────────────┐
                                        │ Notification │
                                        │   Service    │
                                        └──────────────┘
```

## Troubleshooting

### Common Issues

**1. ECR Push Fails**
- Verify AWS credentials are correct
- Ensure ECR repositories exist
- Check IAM permissions for ECR

**2. ECS Task Won't Start**
- Check CloudWatch logs for errors
- Verify task execution role has correct permissions
- Ensure security groups allow required ports

**3. Service Communication Issues**
- Verify services are in the same VPC
- Check security group rules
- Ensure service discovery or environment variables are configured correctly

**4. GitHub Actions Fails**
- Check GitHub Secrets are set correctly
- Verify AWS credentials have necessary permissions
- Review workflow logs for specific errors

## Cleanup

To avoid AWS charges, delete resources when done:

```bash
# Delete ECS services (do this first)
aws ecs update-service --cluster microservices-cluster --service api-gateway-service --desired-count 0
aws ecs delete-service --cluster microservices-cluster --service api-gateway-service

# Delete ECS cluster
aws ecs delete-cluster --cluster microservices-cluster

# Delete ECR repositories
aws ecr delete-repository --repository-name api-gateway --force
aws ecr delete-repository --repository-name user-service --force
aws ecr delete-repository --repository-name product-service --force
aws ecr delete-repository --repository-name order-service --force
aws ecr delete-repository --repository-name notification-service --force

# Delete load balancer, target groups, and other resources via console or CLI
```

## Project Structure

```
ci-cd-demo/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions CI/CD workflow
├── services/
│   ├── api-gateway/            # API Gateway service
│   ├── user-service/           # User management service
│   ├── product-service/        # Product catalog service
│   ├── order-service/          # Order processing service
│   └── notification-service/   # Notification service
├── aws/
│   └── task-definitions/       # ECS task definitions
├── docs/
│   └── PIPELINE.md            # Detailed pipeline explanation
└── README.md                  # This file
```

## Contributing

This is a demonstration project. Feel free to fork and modify for your needs.

## License

MIT License