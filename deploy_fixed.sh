#!/bin/bash

echo "========================================="
echo "Fixed Deployment Script for AML System"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}
DB_PASSWORD=${DB_PASSWORD:-aml_password}

echo ""
echo "Step 1: Cleaning up old containers..."
echo "--------------------------------------"

# Stop and remove only AML containers
AML_CONTAINERS=(
    "aml-backend"
    "aml-frontend" 
    "aml-postgres"
    "aml-redis"
    "aml-nginx"
)

for container in "${AML_CONTAINERS[@]}"; do
    if docker ps -a | grep -q "$container"; then
        echo "Removing $container..."
        docker stop "$container" 2>/dev/null
        docker rm "$container" 2>/dev/null
    fi
done

# Remove old volumes if they exist
echo "Removing old volumes..."
docker volume rm aml-postgres_data aml-redis_data 2>/dev/null || true

echo ""
echo "Step 2: Building images..."
echo "--------------------------"

# Build backend image
docker build -f Dockerfile.backend -t aml-backend:latest .

# Build frontend image
cd aml-frontend
docker build -t aml-frontend:latest .
cd ..

echo ""
echo "Step 3: Starting PostgreSQL..."
echo "------------------------------"

# Start PostgreSQL with init script
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

# Verify database and user creation
echo "Verifying database setup..."
docker exec aml-postgres psql -U postgres -c "\l" | grep aml_database && echo "✓ Database created" || echo "✗ Database creation failed"
docker exec aml-postgres psql -U postgres -c "\du" | grep aml_user && echo "✓ User created" || echo "✗ User creation failed"

echo ""
echo "Step 4: Starting Redis..."
echo "------------------------"

docker run -d \
  --name aml-redis \
  -p 6380:6379 \
  --restart always \
  redis:7-alpine

echo ""
echo "Step 5: Starting Backend..."
echo "---------------------------"

# Get PostgreSQL container IP
POSTGRES_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' aml-postgres)
REDIS_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' aml-redis)

docker run -d \
  --name aml-backend \
  -e DATABASE_URL=postgresql://aml_user:$DB_PASSWORD@$POSTGRES_IP:5432/aml_database \
  -e REDIS_URL=redis://$REDIS_IP:6379/0 \
  -e CORS_ALLOWED_ORIGINS="*" \
  -e SECRET_KEY=your-secret-key-change-in-production \
  -e WEBHOOK_TOKEN=your-webhook-token \
  -p 50000:8000 \
  --restart always \
  aml-backend:latest

echo "Waiting for backend to start..."
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
echo "Step 6: Starting Frontend with Nginx..."
echo "---------------------------------------"

# Create nginx config for frontend
cat > /tmp/nginx.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://host.docker.internal:50000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://host.docker.internal:50000/health;
    }

    location /docs {
        proxy_pass http://host.docker.internal:50000/docs;
    }

    location /openapi.json {
        proxy_pass http://host.docker.internal:50000/openapi.json;
    }
}
EOF

# Start nginx with frontend build
docker run -d \
  --name aml-frontend \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v /tmp/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  -p 8080:80 \
  --add-host=host.docker.internal:host-gateway \
  --restart always \
  nginx:alpine

echo ""
echo "Step 7: Creating test user..."
echo "-----------------------------"

# Create test user via API
sleep 2
curl -X POST http://localhost:50000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123",
    "name": "Admin User"
  }' 2>/dev/null | python3 -m json.tool || echo "User creation via API failed - may already exist"

echo ""
echo "Step 8: Testing deployment..."
echo "-----------------------------"

# Test backend
echo "Testing backend health..."
curl -s http://localhost:50000/health | python3 -m json.tool

# Test authentication
echo ""
echo "Testing authentication..."
curl -X POST http://localhost:50000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123" \
  -s | grep -q "access_token" && echo "✓ Authentication working!" || echo "✗ Authentication failed"

# Test CORS
echo ""
echo "Testing CORS headers..."
curl -I -X OPTIONS http://localhost:50000/api/v1/health \
  -H "Origin: http://$PUBLIC_IP:8080" \
  -H "Access-Control-Request-Method: GET" 2>/dev/null | grep -i "access-control" || echo "No CORS headers found"

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Services running:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "aml"
echo ""
echo "Access the application at:"
echo "  Frontend: http://$PUBLIC_IP:8080"
echo "  Backend API: http://$PUBLIC_IP:50000"
echo "  API Docs: http://$PUBLIC_IP:50000/docs"
echo ""
echo "Default credentials:"
echo "  Email: admin@test.com"
echo "  Password: admin123"
echo ""
echo "Troubleshooting commands:"
echo "  docker logs aml-backend"
echo "  docker logs aml-postgres"
echo "  docker logs aml-frontend"
echo ""