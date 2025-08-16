#!/bin/bash

echo "========================================="
echo "Network Fix Deployment Script"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}
DB_PASSWORD=${DB_PASSWORD:-aml_password}

echo ""
echo "Step 1: Creating Docker network..."
echo "----------------------------------"
docker network create aml-network 2>/dev/null || echo "Network already exists"

echo ""
echo "Step 2: Stopping all AML containers..."
echo "--------------------------------------"
docker stop aml-backend aml-postgres aml-redis aml-frontend aml-nginx 2>/dev/null
docker rm aml-backend aml-postgres aml-redis aml-frontend aml-nginx 2>/dev/null

echo ""
echo "Step 3: Starting PostgreSQL with network..."
echo "------------------------------------------"
docker run -d \
  --name aml-postgres \
  --network aml-network \
  --network-alias postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=$DB_PASSWORD \
  -e POSTGRES_DB=postgres \
  -v $(pwd)/init-db.sql:/docker-entrypoint-initdb.d/init.sql \
  -p 5433:5432 \
  --restart always \
  postgres:15-alpine

echo "Waiting for PostgreSQL to initialize..."
sleep 10

echo ""
echo "Step 4: Starting Redis with network..."
echo "--------------------------------------"
docker run -d \
  --name aml-redis \
  --network aml-network \
  --network-alias redis \
  -p 6380:6379 \
  --restart always \
  redis:7-alpine

echo ""
echo "Step 5: Building backend image..."
echo "---------------------------------"
docker build -f Dockerfile.backend -t aml-backend:latest .

echo ""
echo "Step 6: Starting backend with network..."
echo "----------------------------------------"

# Use localhost for database connection via port mapping
docker run -d \
  --name aml-backend \
  --network aml-network \
  --network-alias backend \
  -e DATABASE_URL="postgresql://aml_user:${DB_PASSWORD}@postgres:5432/aml_database" \
  -e REDIS_URL="redis://redis:6379/0" \
  -e CORS_ALLOWED_ORIGINS="*" \
  -e SECRET_KEY="your-secret-key-change-in-production" \
  -e WEBHOOK_TOKEN="your-webhook-token" \
  -e PYTHONUNBUFFERED=1 \
  -p 8000:50000 \
  --restart always \
  aml-backend:latest

echo ""
echo "Step 7: Waiting for backend to start..."
echo "---------------------------------------"
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✓ Backend is healthy!"
        curl -s http://localhost:8000/health | python3 -m json.tool
        break
    else
        echo "Waiting for backend... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        if [ $RETRY_COUNT -eq 15 ]; then
            echo "Checking backend logs for errors..."
            docker logs aml-backend --tail 20
        fi
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "✗ Backend failed to start. Full logs:"
    docker logs aml-backend
    exit 1
fi

echo ""
echo "Step 8: Building and starting frontend..."
echo "-----------------------------------------"
cd aml-frontend

# Build frontend if needed
if [ ! -d "build" ]; then
    echo "Building frontend..."
    npm install
    REACT_APP_API_URL=http://$PUBLIC_IP:8000/api/v1 npm run build
fi

cd ..

# Start nginx with frontend
docker run -d \
  --name aml-frontend \
  --network aml-network \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro \
  -p 8080:80 \
  --restart always \
  nginx:alpine

echo ""
echo "Step 9: Testing connectivity..."
echo "-------------------------------"

# Test database connection from backend
echo "Testing database connection..."
docker exec aml-backend python3 -c "
from sqlalchemy import create_engine
try:
    engine = create_engine('postgresql://aml_user:$DB_PASSWORD@postgres:5432/aml_database')
    with engine.connect() as conn:
        result = conn.execute('SELECT 1')
        print('✓ Database connection successful')
except Exception as e:
    print(f'✗ Database connection failed: {e}')
" 2>/dev/null || echo "Database test failed"

echo ""
echo "Step 10: Creating test user..."
echo "------------------------------"
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123",
    "name": "Admin User"
  }' 2>/dev/null | python3 -m json.tool || echo "User creation failed (may already exist)"

echo ""
echo "Step 11: Testing authentication..."
echo "----------------------------------"
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123" \
  -s | grep -q "access_token" && echo "✓ Authentication working!" || echo "✗ Authentication failed"

echo ""
echo "========================================="
echo "Network Fix Complete!"
echo "========================================="
echo ""
echo "Services running:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "aml"
echo ""
echo "Network configuration:"
docker network inspect aml-network | grep -A 5 "Containers"
echo ""
echo "Access points:"
echo "  Frontend: http://$PUBLIC_IP:8080"
echo "  Backend API: http://$PUBLIC_IP:8000"
echo "  API Docs: http://$PUBLIC_IP:8000/docs"
echo ""
echo "Troubleshooting:"
echo "  docker logs aml-backend"
echo "  docker exec aml-backend ping postgres"
echo "  ./check_backend.sh"
echo ""