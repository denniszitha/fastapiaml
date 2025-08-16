#!/bin/bash

echo "========================================="
echo "Standalone Deployment (Host Network)"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}
DB_PASSWORD=${DB_PASSWORD:-aml_password}

echo ""
echo "Step 1: Ensuring PostgreSQL is running..."
echo "-----------------------------------------"
if ! docker ps | grep -q aml-postgres; then
    echo "Starting PostgreSQL..."
    docker run -d \
      --name aml-postgres \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD=$DB_PASSWORD \
      -e POSTGRES_DB=postgres \
      -v $(pwd)/init-db.sql:/docker-entrypoint-initdb.d/init.sql \
      -p 5433:5432 \
      --restart always \
      postgres:15-alpine
    
    echo "Waiting for PostgreSQL to initialize..."
    sleep 10
else
    echo "PostgreSQL already running"
fi

echo ""
echo "Step 2: Ensuring Redis is running..."
echo "------------------------------------"
if ! docker ps | grep -q aml-redis; then
    echo "Starting Redis..."
    docker run -d \
      --name aml-redis \
      -p 6380:6379 \
      --restart always \
      redis:7-alpine
else
    echo "Redis already running"
fi

echo ""
echo "Step 3: Fixing database if needed..."
echo "------------------------------------"
docker exec -i aml-postgres psql -U postgres -d aml_database << 'EOF' 2>&1 | grep -v "already exists"
-- Ensure user exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'aml_user') THEN
        CREATE USER aml_user WITH PASSWORD 'aml_password';
    END IF;
END
$$;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE aml_database TO aml_user;
GRANT ALL ON SCHEMA public TO aml_user;
EOF

echo ""
echo "Step 4: Building backend..."
echo "---------------------------"
docker build -f Dockerfile.backend -t aml-backend:latest .

echo ""
echo "Step 5: Stopping old backend..."
echo "-------------------------------"
docker stop aml-backend 2>/dev/null
docker rm aml-backend 2>/dev/null

echo ""
echo "Step 6: Starting backend with host network..."
echo "--------------------------------------------"
docker run -d \
  --name aml-backend \
  --network host \
  -e DATABASE_URL="postgresql://aml_user:${DB_PASSWORD}@localhost:5433/aml_database" \
  -e REDIS_URL="redis://localhost:6380/0" \
  -e CORS_ALLOWED_ORIGINS="*" \
  -e SECRET_KEY="your-secret-key-change-in-production" \
  -e WEBHOOK_TOKEN="your-webhook-token" \
  -e PYTHONUNBUFFERED=1 \
  -e DB_PASSWORD=$DB_PASSWORD \
  -v $(pwd)/app:/app/app:ro \
  --restart always \
  aml-backend:latest

echo ""
echo "Step 7: Waiting for backend..."
echo "------------------------------"
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:50000/health > /dev/null 2>&1; then
        echo "✓ Backend is healthy!"
        curl -s http://localhost:50000/health | python3 -m json.tool
        break
    else
        echo "Waiting... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        if [ $RETRY_COUNT -eq 10 ]; then
            echo "Checking logs..."
            docker logs aml-backend --tail 10
        fi
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

echo ""
echo "Step 8: Testing database connection..."
echo "--------------------------------------"
docker exec aml-backend python3 -c "
from app.db.base import engine
try:
    with engine.connect() as conn:
        result = conn.execute('SELECT current_database()')
        print('✓ Database connected:', result.scalar())
except Exception as e:
    print('✗ Database error:', str(e)[:100])
"

echo ""
echo "Step 9: Creating test user..."
echo "----------------------------"
curl -X POST http://localhost:50000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123",
    "name": "Admin User"
  }' 2>/dev/null | python3 -m json.tool || echo "User may already exist"

echo ""
echo "Step 10: Testing authentication..."
echo "---------------------------------"
curl -X POST http://localhost:50000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123" \
  -s | python3 -m json.tool

echo ""
echo "Step 11: Starting frontend..."
echo "----------------------------"
docker stop aml-frontend 2>/dev/null
docker rm aml-frontend 2>/dev/null

docker run -d \
  --name aml-frontend \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro \
  -p 8080:80 \
  --restart always \
  nginx:alpine

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Services:"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep "aml"
echo ""
echo "Access:"
echo "  Frontend: http://$PUBLIC_IP:8080"
echo "  Backend: http://$PUBLIC_IP:50000"  
echo "  API Docs: http://$PUBLIC_IP:50000/docs"
echo ""
echo "Note: Backend is running on host network mode"
echo "Port 50000 is directly exposed on the host"
echo ""