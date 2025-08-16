#!/bin/bash

echo "========================================="
echo "Working Deployment Script"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}
DB_PASSWORD=${DB_PASSWORD:-aml_password}

echo ""
echo "Step 1: Cleaning up old containers..."
echo "-------------------------------------"
docker stop aml-backend aml-postgres aml-redis aml-frontend 2>/dev/null
docker rm aml-backend aml-postgres aml-redis aml-frontend 2>/dev/null
docker network rm aml-net 2>/dev/null

echo ""
echo "Step 2: Creating fresh network..."
echo "---------------------------------"
docker network create aml-net

echo ""
echo "Step 3: Starting PostgreSQL..."
echo "------------------------------"
docker run -d \
  --name aml-postgres \
  --network aml-net \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=$DB_PASSWORD \
  -e POSTGRES_DB=postgres \
  -v $(pwd)/init-db.sql:/docker-entrypoint-initdb.d/init.sql \
  -p 5433:5432 \
  --restart always \
  postgres:15-alpine

echo "Waiting for PostgreSQL..."
sleep 10

# Verify PostgreSQL is ready
docker exec aml-postgres pg_isready -U postgres && echo "✓ PostgreSQL ready" || echo "✗ PostgreSQL not ready"

echo ""
echo "Step 4: Starting Redis..."
echo "------------------------"
docker run -d \
  --name aml-redis \
  --network aml-net \
  -p 6380:6379 \
  --restart always \
  redis:7-alpine

echo ""
echo "Step 5: Building backend with SQLite fallback..."
echo "------------------------------------------------"
docker build -f Dockerfile.backend -t aml-backend:latest .

echo ""
echo "Step 6: Starting backend (SQLite mode first)..."
echo "-----------------------------------------------"
# Start with SQLite to ensure backend works
docker run -d \
  --name aml-backend \
  --network aml-net \
  -e USE_SQLITE=true \
  -e CORS_ALLOWED_ORIGINS="*" \
  -e SECRET_KEY="your-secret-key-change-in-production" \
  -e WEBHOOK_TOKEN="your-webhook-token" \
  -e PYTHONUNBUFFERED=1 \
  -p 8000:50000 \
  -v $(pwd)/app:/app/app:ro \
  --restart always \
  aml-backend:latest

echo ""
echo "Step 7: Waiting for backend to start..."
echo "---------------------------------------"
MAX_RETRIES=20
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✓ Backend is healthy!"
        curl -s http://localhost:8000/health | python3 -m json.tool
        break
    else
        echo "Waiting... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "✗ Backend failed to start. Checking logs..."
    docker logs aml-backend --tail 30
    exit 1
fi

echo ""
echo "Step 8: Testing API endpoints..."
echo "--------------------------------"

# Test health
echo "Health check:"
curl -s http://localhost:8000/health | python3 -m json.tool

# Create user
echo ""
echo "Creating test user:"
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123",
    "name": "Admin User"
  }' 2>/dev/null | python3 -m json.tool || echo "User may already exist"

# Test login
echo ""
echo "Testing authentication:"
RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123")

if echo "$RESPONSE" | grep -q "access_token"; then
    echo "✓ Authentication successful!"
else
    echo "✗ Authentication failed"
    echo "$RESPONSE"
fi

echo ""
echo "Step 9: Starting frontend..."
echo "---------------------------"
cd aml-frontend

# Build frontend if needed
if [ ! -d "build" ]; then
    echo "Building frontend..."
    npm install
    REACT_APP_API_URL=http://$PUBLIC_IP:8000/api/v1 npm run build
fi

cd ..

docker run -d \
  --name aml-frontend \
  --network aml-net \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -p 8080:80 \
  --restart always \
  nginx:alpine

echo ""
echo "Step 10: Optionally switch to PostgreSQL..."
echo "------------------------------------------"
echo "To switch backend to PostgreSQL, run:"
echo ""
echo "docker stop aml-backend && docker rm aml-backend"
echo "docker run -d \\"
echo "  --name aml-backend \\"
echo "  --network aml-net \\"
echo "  -e DB_HOST=aml-postgres \\"
echo "  -e DB_PORT=5432 \\"
echo "  -e DB_USER=aml_user \\"
echo "  -e DB_PASSWORD=$DB_PASSWORD \\"
echo "  -e DB_NAME=aml_database \\"
echo "  -e USE_SQLITE=false \\"
echo "  -e CORS_ALLOWED_ORIGINS=\"*\" \\"
echo "  -e SECRET_KEY=\"your-secret-key-change-in-production\" \\"
echo "  -e PYTHONUNBUFFERED=1 \\"
echo "  -p 8000:50000 \\"
echo "  -v \$(pwd)/app:/app/app:ro \\"
echo "  --restart always \\"
echo "  aml-backend:latest"

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Services running:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "aml"
echo ""
echo "Access points:"
echo "  Frontend: http://$PUBLIC_IP:8080"
echo "  Backend API: http://$PUBLIC_IP:8000"
echo "  API Docs: http://$PUBLIC_IP:8000/docs"
echo ""
echo "Database: SQLite (local file)"
echo "To switch to PostgreSQL, see instructions above"
echo ""
echo "Default credentials:"
echo "  Email: admin@test.com"
echo "  Password: admin123"
echo ""