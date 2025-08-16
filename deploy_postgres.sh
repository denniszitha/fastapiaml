#!/bin/bash

echo "========================================="
echo "PostgreSQL Deployment Script"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}
DB_PASSWORD=${DB_PASSWORD:-aml_password}

echo ""
echo "Step 1: Stopping and removing old containers..."
echo "-----------------------------------------------"
docker stop aml-backend aml-postgres aml-redis aml-frontend 2>/dev/null
docker rm aml-backend aml-postgres aml-redis aml-frontend 2>/dev/null

echo ""
echo "Step 2: Creating Docker network..."
echo "----------------------------------"
docker network create aml-network 2>/dev/null || echo "Network already exists"

echo ""
echo "Step 3: Starting PostgreSQL..."
echo "------------------------------"
docker run -d \
  --name aml-postgres \
  --network aml-network \
  --hostname postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=$DB_PASSWORD \
  -e POSTGRES_DB=postgres \
  -v $(pwd)/init-db.sql:/docker-entrypoint-initdb.d/init.sql:ro \
  -p 5433:5432 \
  --health-cmd="pg_isready -U postgres" \
  --health-interval=10s \
  --health-timeout=5s \
  --health-retries=5 \
  --restart always \
  postgres:15-alpine

echo "Waiting for PostgreSQL to be healthy..."
for i in {1..30}; do
    if docker exec aml-postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "✓ PostgreSQL is ready!"
        break
    fi
    echo -n "."
    sleep 2
done

# Ensure database and user exist
echo ""
echo "Step 4: Ensuring database and user exist..."
echo "------------------------------------------"
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
EOF

echo ""
echo "Step 5: Starting Redis..."
echo "------------------------"
docker run -d \
  --name aml-redis \
  --network aml-network \
  --hostname redis \
  -p 6380:6379 \
  --restart always \
  redis:7-alpine

echo ""
echo "Step 6: Building backend..."
echo "---------------------------"
docker build -f Dockerfile.backend -t aml-backend:latest .

echo ""
echo "Step 7: Starting backend with PostgreSQL..."
echo "------------------------------------------"
docker run -d \
  --name aml-backend \
  --network aml-network \
  --hostname backend \
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
  -p 8000:50000 \
  -v $(pwd)/app:/app/app:ro \
  --restart always \
  aml-backend:latest

echo ""
echo "Step 8: Monitoring backend startup..."
echo "-------------------------------------"
echo "Waiting for backend to connect to PostgreSQL..."

# Show logs while waiting
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo ""
        echo "✓ Backend is healthy!"
        curl -s http://localhost:8000/health | python3 -m json.tool
        break
    fi
    
    if [ $i -eq 10 ] || [ $i -eq 20 ]; then
        echo ""
        echo "Backend logs:"
        docker logs aml-backend --tail 10
        echo ""
    fi
    
    echo -n "."
    sleep 2
done

# Final check
if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo ""
    echo "✗ Backend failed to start. Full logs:"
    docker logs aml-backend
    echo ""
    echo "PostgreSQL connectivity test from backend container:"
    docker exec aml-backend ping -c 2 postgres 2>&1 || echo "Cannot reach postgres host"
    exit 1
fi

echo ""
echo "Step 9: Testing database connection from backend..."
echo "--------------------------------------------------"
docker exec aml-backend python3 -c "
from app.db.base import engine
from sqlalchemy import text
try:
    with engine.connect() as conn:
        result = conn.execute(text('SELECT current_database(), current_user'))
        db, user = result.first()
        print(f'✓ Connected to database: {db} as user: {user}')
except Exception as e:
    print(f'✗ Database connection error: {e}')
"

echo ""
echo "Step 10: Creating test user..."
echo "------------------------------"
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123",
    "name": "Admin User"
  }' 2>/dev/null | python3 -m json.tool || echo "User creation failed"

echo ""
echo "Step 11: Testing authentication..."
echo "----------------------------------"
RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123")

if echo "$RESPONSE" | grep -q "access_token"; then
    echo "✓ Authentication successful!"
    echo "$RESPONSE" | python3 -m json.tool | head -5
else
    echo "✗ Authentication failed"
    echo "$RESPONSE"
fi

echo ""
echo "Step 12: Starting frontend..."
echo "----------------------------"
cd aml-frontend

if [ ! -d "build" ]; then
    echo "Building frontend..."
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
echo "PostgreSQL Deployment Complete!"
echo "========================================="
echo ""
echo "Services running:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "aml"
echo ""
echo "Network details:"
docker network inspect aml-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}'
echo ""
echo "Access points:"
echo "  Frontend: http://$PUBLIC_IP:8080"
echo "  Backend API: http://$PUBLIC_IP:8000"
echo "  API Docs: http://$PUBLIC_IP:8000/docs"
echo "  PostgreSQL: localhost:5433"
echo ""
echo "Credentials:"
echo "  App: admin@test.com / admin123"
echo "  DB: aml_user / $DB_PASSWORD"
echo ""
echo "Troubleshooting:"
echo "  docker logs aml-backend -f"
echo "  docker exec -it aml-postgres psql -U postgres"
echo "  docker exec aml-backend ping postgres"
echo ""