#!/bin/bash

echo "========================================="
echo "Fixed PostgreSQL Deployment Script"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}
DB_PASSWORD=${DB_PASSWORD:-aml_password}

echo ""
echo "Step 1: Complete cleanup..."
echo "---------------------------"
docker stop aml-backend aml-postgres aml-redis aml-frontend 2>/dev/null
docker rm aml-backend aml-postgres aml-redis aml-frontend 2>/dev/null
docker network rm aml-network 2>/dev/null

echo ""
echo "Step 2: Create Docker network..."
echo "--------------------------------"
docker network create --driver bridge aml-network

echo ""
echo "Step 3: Start PostgreSQL..."
echo "---------------------------"
docker run -d \
  --name aml-postgres \
  --network aml-network \
  --network-alias postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=$DB_PASSWORD \
  -e POSTGRES_DB=postgres \
  -v $(pwd)/init-db.sql:/docker-entrypoint-initdb.d/init.sql:ro \
  -p 5433:5432 \
  --restart always \
  postgres:15-alpine

echo "Waiting for PostgreSQL to initialize..."
sleep 15

# Verify PostgreSQL is ready
docker exec aml-postgres pg_isready -U postgres
if [ $? -eq 0 ]; then
    echo "✓ PostgreSQL is ready"
else
    echo "✗ PostgreSQL not ready, waiting more..."
    sleep 10
fi

echo ""
echo "Step 4: Create database and user..."
echo "-----------------------------------"
docker exec aml-postgres psql -U postgres << EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'aml_user') THEN
        CREATE USER aml_user WITH PASSWORD '$DB_PASSWORD';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE aml_database OWNER aml_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'aml_database')\\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE aml_database TO aml_user;

-- Connect to aml_database and grant schema privileges
\\c aml_database
GRANT ALL ON SCHEMA public TO aml_user;
GRANT CREATE ON SCHEMA public TO aml_user;
EOF

echo ""
echo "Step 5: Start Redis..."
echo "---------------------"
docker run -d \
  --name aml-redis \
  --network aml-network \
  --network-alias redis \
  -p 6380:6379 \
  --restart always \
  redis:7-alpine

echo ""
echo "Step 6: Build backend with fixed imports..."
echo "-------------------------------------------"
docker build -f Dockerfile.backend -t aml-backend:fixed .

echo ""
echo "Step 7: Start backend..."
echo "------------------------"
docker run -d \
  --name aml-backend \
  --network aml-network \
  --network-alias backend \
  -e DATABASE_URL="postgresql://aml_user:${DB_PASSWORD}@postgres:5432/aml_database" \
  -e DB_HOST=postgres \
  -e DB_PORT=5432 \
  -e DB_USER=aml_user \
  -e DB_PASSWORD=$DB_PASSWORD \
  -e DB_NAME=aml_database \
  -e REDIS_URL="redis://redis:6379/0" \
  -e CORS_ALLOWED_ORIGINS="*" \
  -e SECRET_KEY="your-secret-key-change-in-production" \
  -e WEBHOOK_TOKEN="your-webhook-token" \
  -e PYTHONUNBUFFERED=1 \
  -e PYTHONDONTWRITEBYTECODE=1 \
  -p 8000:50000 \
  -v $(pwd)/app:/app/app:ro \
  --restart always \
  aml-backend:fixed

echo ""
echo "Step 8: Monitor backend startup..."
echo "----------------------------------"
echo "Waiting for backend to start (this may take up to 60 seconds)..."

MAX_RETRIES=30
RETRY_COUNT=0
SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo ""
        echo "✓ Backend is healthy!"
        curl -s http://localhost:8000/health | python3 -m json.tool
        SUCCESS=true
        break
    fi
    
    # Show logs periodically
    if [ $((RETRY_COUNT % 10)) -eq 0 ] && [ $RETRY_COUNT -gt 0 ]; then
        echo ""
        echo "Still waiting... checking logs:"
        docker logs aml-backend --tail 5 2>&1 | grep -E "(ERROR|WARNING|INFO|Successfully connected|Failed|Error)"
    else
        echo -n "."
    fi
    
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ "$SUCCESS" = false ]; then
    echo ""
    echo "✗ Backend failed to start properly. Detailed logs:"
    docker logs aml-backend --tail 50
    echo ""
    echo "Testing network connectivity:"
    docker exec aml-backend ping -c 2 postgres || echo "Cannot ping postgres"
    docker exec aml-backend nslookup postgres || echo "Cannot resolve postgres"
    echo ""
    echo "PostgreSQL status:"
    docker exec aml-postgres pg_isready -U postgres
    exit 1
fi

echo ""
echo "Step 9: Test database connection..."
echo "-----------------------------------"
docker exec aml-backend python3 -c "
from app.db.base import engine
from sqlalchemy import text
try:
    with engine.connect() as conn:
        result = conn.execute(text('SELECT current_database(), current_user, version()'))
        db, user, version = result.first()
        print(f'✓ Connected to: {db}')
        print(f'  User: {user}')
        print(f'  PostgreSQL: {version[:20]}...')
except Exception as e:
    print(f'✗ Database error: {e}')
" || echo "Database test failed"

echo ""
echo "Step 10: Create test user..."
echo "----------------------------"
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123",
    "name": "Admin User"
  }' 2>/dev/null | python3 -m json.tool || echo "User may already exist"

echo ""
echo "Step 11: Test authentication..."
echo "-------------------------------"
RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123")

if echo "$RESPONSE" | grep -q "access_token"; then
    echo "✓ Authentication working!"
else
    echo "✗ Authentication failed: $RESPONSE"
fi

echo ""
echo "Step 12: Start frontend..."
echo "--------------------------"
cd aml-frontend
if [ ! -d "build" ]; then
    npm install
    REACT_APP_API_URL=http://$PUBLIC_IP:8000/api/v1 npm run build
fi
cd ..

docker run -d \
  --name aml-frontend \
  --network aml-network \
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
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "aml"
echo ""
echo "Network Info:"
echo "-------------"
for container in aml-postgres aml-redis aml-backend; do
    IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container 2>/dev/null)
    echo "$container: $IP"
done
echo ""
echo "Access:"
echo "  Frontend: http://$PUBLIC_IP:8080"
echo "  Backend: http://$PUBLIC_IP:8000"
echo "  API Docs: http://$PUBLIC_IP:8000/docs"
echo ""
echo "Debugging:"
echo "  docker logs aml-backend -f"
echo "  docker exec aml-backend ping postgres"
echo "  docker exec -it aml-postgres psql -U aml_user -d aml_database"
echo ""