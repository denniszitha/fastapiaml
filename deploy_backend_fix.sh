#!/bin/bash

echo "========================================="
echo "Backend Fix Deployment Script"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}
DB_PASSWORD=${DB_PASSWORD:-aml_password}

echo ""
echo "Step 1: Stopping backend container..."
echo "-------------------------------------"
docker stop aml-backend 2>/dev/null
docker rm aml-backend 2>/dev/null

echo ""
echo "Step 2: Rebuilding backend with correct port..."
echo "-----------------------------------------------"
docker build -f Dockerfile.backend -t aml-backend:latest .

echo ""
echo "Step 3: Creating Docker network if not exists..."
echo "------------------------------------------------"
docker network create aml-network 2>/dev/null || echo "Network already exists"

echo ""
echo "Step 4: Ensuring PostgreSQL is running..."
echo "-----------------------------------------"
if ! docker ps | grep -q aml-postgres; then
    echo "Starting PostgreSQL..."
    docker run -d \
      --name aml-postgres \
      --network aml-network \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD=$DB_PASSWORD \
      -e POSTGRES_DB=postgres \
      -v $(pwd)/init-db.sql:/docker-entrypoint-initdb.d/init.sql \
      -p 5433:5432 \
      --restart always \
      postgres:15-alpine
    
    echo "Waiting for PostgreSQL..."
    sleep 10
fi

echo ""
echo "Step 5: Ensuring Redis is running..."
echo "------------------------------------"
if ! docker ps | grep -q aml-redis; then
    echo "Starting Redis..."
    docker run -d \
      --name aml-redis \
      --network aml-network \
      -p 6380:6379 \
      --restart always \
      redis:7-alpine
fi

echo ""
echo "Step 6: Starting backend with correct configuration..."
echo "------------------------------------------------------"
docker run -d \
  --name aml-backend \
  --network aml-network \
  -e DATABASE_URL=postgresql://aml_user:$DB_PASSWORD@aml-postgres:5432/aml_database \
  -e REDIS_URL=redis://aml-redis:6379/0 \
  -e CORS_ALLOWED_ORIGINS="*" \
  -e SECRET_KEY=your-secret-key-change-in-production \
  -e WEBHOOK_TOKEN=your-webhook-token \
  -e PYTHONUNBUFFERED=1 \
  -p 8000:50000 \
  --restart always \
  aml-backend:latest

echo ""
echo "Step 7: Waiting for backend to be ready..."
echo "------------------------------------------"
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✓ Backend is healthy!"
        curl -s http://localhost:8000/health | python3 -m json.tool
        break
    else
        echo "Waiting for backend... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        if [ $RETRY_COUNT -eq 10 ]; then
            echo "Checking backend logs..."
            docker logs aml-backend --tail 10
        fi
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "✗ Backend failed to start. Checking logs..."
    docker logs aml-backend
    exit 1
fi

echo ""
echo "Step 8: Creating test user..."
echo "-----------------------------"
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123",
    "name": "Admin User"
  }' 2>/dev/null | python3 -m json.tool || echo "User may already exist"

echo ""
echo "Step 9: Testing authentication..."
echo "---------------------------------"
TOKEN=$(curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123" \
  -s | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)

if [ -n "$TOKEN" ]; then
    echo "✓ Authentication successful!"
    echo "Token: ${TOKEN:0:20}..."
else
    echo "✗ Authentication failed"
fi

echo ""
echo "Step 10: Testing CORS..."
echo "------------------------"
curl -I -X OPTIONS http://localhost:8000/api/v1/health \
  -H "Origin: http://$PUBLIC_IP:8080" \
  -H "Access-Control-Request-Method: GET" 2>/dev/null | grep -i "access-control"

echo ""
echo "========================================="
echo "Backend Fix Complete!"
echo "========================================="
echo ""
echo "Services status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "aml"
echo ""
echo "Access points:"
echo "  Backend API: http://$PUBLIC_IP:8000"
echo "  API Docs: http://$PUBLIC_IP:8000/docs"
echo "  Health: http://$PUBLIC_IP:8000/health"
echo ""
echo "Test commands:"
echo "  curl http://localhost:8000/health"
echo "  docker logs aml-backend"
echo "  ./check_backend.sh"
echo ""