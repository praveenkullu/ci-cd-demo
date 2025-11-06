#!/bin/bash

# Local Testing Script
# Builds and runs all services locally with Docker

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${YELLOW}➜${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

print_info "Stopping any existing containers..."
docker-compose down 2>/dev/null || true

print_info "Building Docker images..."

# Build all services
cd services/notification-service
docker build -t notification-service:local .
cd ../..

cd services/user-service
docker build -t user-service:local .
cd ../..

cd services/product-service
docker build -t product-service:local .
cd ../..

cd services/order-service
docker build -t order-service:local .
cd ../..

cd services/api-gateway
docker build -t api-gateway:local .
cd ../..

print_success "All images built successfully!"

print_info "Starting services..."

# Run services
docker run -d --name notification-service -p 3004:3004 notification-service:local
docker run -d --name user-service -p 3001:3001 user-service:local
docker run -d --name product-service -p 3002:3002 product-service:local
docker run -d --name order-service -p 3003:3003 \
    -e NOTIFICATION_SERVICE_URL=http://host.docker.internal:3004 \
    order-service:local
docker run -d --name api-gateway -p 3000:3000 \
    -e USER_SERVICE_URL=http://host.docker.internal:3001 \
    -e PRODUCT_SERVICE_URL=http://host.docker.internal:3002 \
    -e ORDER_SERVICE_URL=http://host.docker.internal:3003 \
    -e NOTIFICATION_SERVICE_URL=http://host.docker.internal:3004 \
    api-gateway:local

print_success "All services started!"

echo ""
echo "Services running at:"
echo "  API Gateway:         http://localhost:3000"
echo "  User Service:        http://localhost:3001"
echo "  Product Service:     http://localhost:3002"
echo "  Order Service:       http://localhost:3003"
echo "  Notification Service: http://localhost:3004"
echo ""
echo "Test the API:"
echo "  curl http://localhost:3000/health"
echo "  curl http://localhost:3000/api/users"
echo ""
echo "To stop all services:"
echo "  docker stop api-gateway user-service product-service order-service notification-service"
echo "  docker rm api-gateway user-service product-service order-service notification-service"
