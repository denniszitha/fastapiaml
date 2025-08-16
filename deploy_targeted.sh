#!/bin/bash

echo "========================================="
echo "Targeted Deployment for AML System"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}

echo ""
echo "Step 1: Stopping ONLY AML containers..."
echo "-----------------------------------------"

# List of AML-specific container names
AML_CONTAINERS=(
    "aml-backend"
    "aml-backend-simple"
    "aml-frontend"
    "aml-frontend-simple"
    "aml-postgres"
    "aml-redis"
    "aml-nginx"
    "aml_backend"
    "aml_frontend"
    "aml_postgres"
    "aml_redis"
    "aml_nginx"
)

# Stop only AML containers
for container in "${AML_CONTAINERS[@]}"; do
    if docker ps -a | grep -q "$container"; then
        echo "Stopping $container..."
        docker stop "$container" 2>/dev/null
        docker rm "$container" 2>/dev/null
    fi
done

echo ""
echo "Step 2: Checking other running containers..."
echo "--------------------------------------------"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v "aml"

echo ""
echo "Step 3: Building AML backend..."
echo "--------------------------------"
docker build -f Dockerfile.simple -t aml-backend-simple .

echo ""
echo "Step 4: Starting AML backend..."
echo "--------------------------------"
docker run -d \
  --name aml-backend \
  -p 50000:50000 \
  -e CORS_ALLOWED_ORIGINS="*" \
  --restart always \
  aml-backend-simple

echo ""
echo "Step 5: Waiting for backend to be ready..."
echo "------------------------------------------"
sleep 5

# Test backend health
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:50000/health > /dev/null 2>&1; then
        echo "✓ Backend is healthy!"
        break
    else
        echo "Waiting for backend... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

echo ""
echo "Step 6: Testing authentication..."
echo "----------------------------------"
if command -v python3 &> /dev/null; then
    python3 test_auth.py http://localhost:50000
else
    # Fallback to curl test
    curl -X POST http://localhost:50000/api/v1/auth/login \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=admin@test.com&password=admin123" \
      -s | grep -q "access_token" && echo "✓ Authentication working!" || echo "✗ Authentication failed"
fi

echo ""
echo "Step 7: Building and starting frontend..."
echo "-----------------------------------------"
cd aml-frontend

# Create production environment file
cat > .env.production.local << EOF
REACT_APP_API_URL=http://$PUBLIC_IP:50000/api/v1
EOF

# Check if node_modules exists, if not install
if [ ! -d "node_modules" ]; then
    echo "Installing frontend dependencies..."
    npm install
fi

# Build frontend
echo "Building frontend..."
npm run build

# Start frontend with serve
echo "Starting frontend server..."
docker run -d \
  --name aml-frontend \
  -p 8080:80 \
  -v $(pwd)/build:/usr/share/nginx/html:ro \
  --restart always \
  nginx:alpine

cd ..

echo ""
echo "Step 8: Verifying deployment..."
echo "--------------------------------"

# Check if services are running
echo "Running AML containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "aml"

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "AML System is running at:"
echo "  Frontend: http://$PUBLIC_IP:8080"
echo "  Backend: http://$PUBLIC_IP:50000"
echo "  API Docs: http://$PUBLIC_IP:50000/docs"
echo ""
echo "Login credentials:"
echo "  Email: admin@test.com"
echo "  Password: admin123"
echo ""
echo "Commands:"
echo "  View logs: docker logs aml-backend"
echo "  Stop AML: docker stop aml-backend aml-frontend"
echo "  Restart: docker restart aml-backend aml-frontend"
echo ""
echo "Other services were NOT affected by this deployment."
echo ""