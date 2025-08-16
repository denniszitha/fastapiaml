#!/bin/bash

# ============================================
# FRONTEND DEPLOYMENT COMPLETION SCRIPT
# ============================================
# This script completes the frontend deployment
# when backend is already running
# ============================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PUBLIC_IP=${PUBLIC_IP:-$(curl -s http://checkip.amazonaws.com || echo "localhost")}
FRONTEND_PORT=${FRONTEND_PORT:-8888}
BACKEND_PORT=${BACKEND_PORT:-8000}

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}COMPLETING FRONTEND DEPLOYMENT${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Public IP: $PUBLIC_IP"
echo "  Frontend Port: $FRONTEND_PORT"
echo "  Backend Port: $BACKEND_PORT"
echo ""

# Check if backend is running
echo -e "${GREEN}Step 1: Verifying backend is running...${NC}"
echo "----------------------------------------"
curl -s http://localhost:$BACKEND_PORT/health > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Backend is running on port $BACKEND_PORT"
else
    echo -e "${RED}✗ Backend is not accessible on port $BACKEND_PORT${NC}"
    echo "Please ensure backend is running first."
    exit 1
fi

# Stop any existing frontend container
echo ""
echo -e "${GREEN}Step 2: Cleaning up old frontend...${NC}"
echo "-----------------------------------"
sudo docker stop aml-frontend 2>/dev/null || true
sudo docker rm aml-frontend 2>/dev/null || true
echo "✓ Cleanup complete"

# Check if build directory exists
echo ""
echo -e "${GREEN}Step 3: Checking frontend build...${NC}"
echo "----------------------------------"
if [ -d "aml-frontend/build" ] && [ -f "aml-frontend/build/index.html" ]; then
    echo "✓ Frontend build exists"
    echo "  Do you want to rebuild? (y/n): "
    read -n 1 -r REBUILD
    echo ""
else
    echo "⚠ Frontend build not found"
    REBUILD="Y"
fi

# Build frontend if needed
if [[ $REBUILD =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}Step 4: Building frontend...${NC}"
    echo "----------------------------"
    cd aml-frontend
    
    # Clean old build
    rm -rf build node_modules package-lock.json
    
    # Install dependencies
    echo "Installing dependencies..."
    npm install --legacy-peer-deps || npm install --force
    
    # Set environment variables for build
    export REACT_APP_API_URL=http://$PUBLIC_IP:$BACKEND_PORT/api/v1
    export REACT_APP_ENVIRONMENT=production
    export PUBLIC_URL=/
    
    echo "Building React application..."
    echo "  API URL: $REACT_APP_API_URL"
    
    # Build with error handling
    npm run build || {
        echo -e "${RED}Build failed. Trying with reduced memory...${NC}"
        export NODE_OPTIONS="--max-old-space-size=2048"
        npm run build
    }
    
    if [ ! -f "build/index.html" ]; then
        echo -e "${RED}✗ Build failed - index.html not found${NC}"
        echo "Creating minimal index.html for testing..."
        mkdir -p build
        cat > build/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>AML Monitor</title>
</head>
<body>
    <div id="root">
        <div style="padding: 50px; text-align: center; font-family: sans-serif;">
            <h1>AML Monitor - Build Error</h1>
            <p>The React build failed. Please check the logs.</p>
            <p>Backend API Status: <span id="api-status">Checking...</span></p>
            <hr />
            <p><a href="/api/v1/docs" target="_blank">API Documentation</a></p>
        </div>
    </div>
    <script>
        fetch('/api/v1/health')
            .then(r => r.json())
            .then(d => document.getElementById('api-status').innerHTML = '✓ Connected')
            .catch(e => document.getElementById('api-status').innerHTML = '✗ Not Connected: ' + e.message);
    </script>
</body>
</html>
EOF
    else
        echo "✓ Frontend built successfully"
    fi
    
    cd ..
else
    echo "  Skipping rebuild, using existing build"
fi

# Create nginx configuration
echo ""
echo -e "${GREEN}Step 5: Creating nginx configuration...${NC}"
echo "---------------------------------------"
mkdir -p nginx
cat > nginx/frontend.conf << EOF
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html index.htm;
    
    # Enable gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml application/atom+xml image/svg+xml text/javascript;
    
    # Frontend application
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
    
    # API proxy to backend
    location /api/ {
        proxy_pass http://172.17.0.1:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Allow CORS
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
    }
    
    # Alternative API proxy endpoints to try
    location /api-host/ {
        proxy_pass http://host.docker.internal:$BACKEND_PORT/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
    
    location /api-docker/ {
        proxy_pass http://aml-backend:$BACKEND_PORT/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
    
    # Health check
    location /health {
        proxy_pass http://172.17.0.1:$BACKEND_PORT/health;
        proxy_http_version 1.1;
    }
    
    # API documentation
    location /docs {
        proxy_pass http://172.17.0.1:$BACKEND_PORT/docs;
        proxy_http_version 1.1;
    }
    
    location /openapi.json {
        proxy_pass http://172.17.0.1:$BACKEND_PORT/openapi.json;
        proxy_http_version 1.1;
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
EOF
echo "✓ Nginx configuration created"

# Start frontend container
echo ""
echo -e "${GREEN}Step 6: Starting frontend container...${NC}"
echo "--------------------------------------"

# Try to connect to existing network or create new one
sudo docker network connect aml-network aml-frontend 2>/dev/null || true

# Run frontend container with multiple host configurations
sudo docker run -d \
  --name aml-frontend \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/frontend.conf:/etc/nginx/conf.d/default.conf:ro \
  -p $FRONTEND_PORT:80 \
  --add-host=host.docker.internal:host-gateway \
  --add-host=aml-backend:172.17.0.1 \
  --restart always \
  nginx:alpine

# Try to connect to network after creation
sudo docker network connect aml-network aml-frontend 2>/dev/null || true

echo "Waiting for frontend to start..."
sleep 5

# Verify frontend is running
sudo docker ps | grep aml-frontend > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Frontend container started"
else
    echo -e "${RED}✗ Frontend container failed to start${NC}"
    echo "Checking logs:"
    sudo docker logs aml-frontend --tail 20
    exit 1
fi

# Test frontend
echo ""
echo -e "${GREEN}Step 7: Testing frontend...${NC}"
echo "---------------------------"

# Test nginx is responding
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✓ Frontend responding: HTTP $FRONTEND_STATUS"
else
    echo -e "${YELLOW}⚠ Frontend returned: HTTP $FRONTEND_STATUS${NC}"
fi

# Test if we get HTML content
HTML_CHECK=$(curl -s http://localhost:$FRONTEND_PORT | grep -c "</html>" || echo 0)
if [ "$HTML_CHECK" -gt 0 ]; then
    echo "✓ HTML content served"
else
    echo -e "${YELLOW}⚠ HTML content check failed${NC}"
fi

# Test API proxy
echo ""
echo -e "${GREEN}Step 8: Testing API proxy...${NC}"
echo "----------------------------"

# Try different proxy endpoints
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT/api/v1/health 2>/dev/null || echo "000")
if [ "$API_STATUS" = "200" ]; then
    echo "✓ API proxy working via /api/"
else
    echo -e "${YELLOW}⚠ Primary API proxy returned: HTTP $API_STATUS${NC}"
    
    # Try alternative endpoints
    echo "Trying alternative proxy configurations..."
    
    # Test direct backend access
    DIRECT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$BACKEND_PORT/health)
    echo "  Direct backend: HTTP $DIRECT_STATUS"
    
    # Check nginx error log
    echo "  Checking nginx errors:"
    sudo docker exec aml-frontend tail -5 /var/log/nginx/error.log 2>/dev/null || echo "    No errors found"
fi

# Final status
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}FRONTEND DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${BLUE}Access the application:${NC}"
echo "  Local: http://localhost:$FRONTEND_PORT"
echo "  Public: http://$PUBLIC_IP:$FRONTEND_PORT"
echo ""
echo -e "${BLUE}Backend API:${NC}"
echo "  Direct: http://$PUBLIC_IP:$BACKEND_PORT"
echo "  Via Proxy: http://$PUBLIC_IP:$FRONTEND_PORT/api/v1"
echo ""
echo -e "${BLUE}API Documentation:${NC}"
echo "  http://$PUBLIC_IP:$BACKEND_PORT/docs"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "  View logs: sudo docker logs aml-frontend"
echo "  Restart: sudo docker restart aml-frontend"
echo "  Rebuild: ./complete_frontend_deployment.sh (choose 'y' to rebuild)"
echo ""

# Show container status
echo -e "${BLUE}Container Status:${NC}"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|aml-frontend"