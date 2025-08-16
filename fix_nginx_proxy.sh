#!/bin/bash

# ============================================
# QUICK NGINX PROXY FIX
# ============================================
# Fixes the nginx proxy configuration immediately
# without rebuilding the React app
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FRONTEND_PORT=8888
BACKEND_PORT=8000

echo -e "${GREEN}QUICK NGINX PROXY FIX${NC}"
echo "===================="
echo ""

# Create fixed nginx config
echo "1. Creating fixed nginx configuration..."
cat > /tmp/nginx-fix.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Main app
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # API proxy - all variations
    location /api/v1 {
        proxy_pass http://172.17.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;
        
        # Handle preflight
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Length' 0;
            return 204;
        }
    }
    
    # Alternative with trailing slash
    location /api/ {
        proxy_pass http://172.17.0.1:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    # Specific auth endpoints
    location ~ ^/api/v1/auth/(login|register|logout|me) {
        proxy_pass http://172.17.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Content-Type application/json;
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;
    }
    
    # Health check
    location /health {
        proxy_pass http://172.17.0.1:8000/health;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
}
EOF

# Update container
echo "2. Updating frontend container..."
sudo docker cp /tmp/nginx-fix.conf aml-frontend:/etc/nginx/conf.d/default.conf
sudo docker exec aml-frontend nginx -s reload

echo "3. Testing API proxy..."
sleep 2

# Test health endpoint
HEALTH=$(curl -s http://localhost:$FRONTEND_PORT/api/v1/health 2>/dev/null || echo "failed")
if [[ "$HEALTH" == *"healthy"* ]] || [[ "$HEALTH" == *"ok"* ]]; then
    echo -e "${GREEN}✓ API proxy is working${NC}"
else
    echo -e "${YELLOW}⚠ API proxy may need adjustment${NC}"
    
    # Try alternative
    echo "   Trying alternative configuration..."
    
    # Try with host.docker.internal
    cat > /tmp/nginx-fix2.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://host.docker.internal:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
}
EOF
    
    sudo docker cp /tmp/nginx-fix2.conf aml-frontend:/etc/nginx/conf.d/default.conf
    sudo docker exec aml-frontend nginx -s reload
    sleep 2
    
    HEALTH2=$(curl -s http://localhost:$FRONTEND_PORT/api/v1/health 2>/dev/null || echo "failed")
    if [[ "$HEALTH2" == *"healthy"* ]] || [[ "$HEALTH2" == *"ok"* ]]; then
        echo -e "${GREEN}✓ Alternative proxy configuration works${NC}"
    fi
fi

# Show how to test
echo ""
echo -e "${GREEN}Fix Applied!${NC}"
echo ""
echo "Test the API connection:"
echo "  curl http://localhost:$FRONTEND_PORT/api/v1/health"
echo ""
echo "Test login:"
echo "  curl -X POST http://localhost:$FRONTEND_PORT/api/v1/auth/login \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"username\":\"admin\",\"password\":\"admin123\"}'"
echo ""
echo "In browser:"
echo "  1. Open http://your-ip:$FRONTEND_PORT"
echo "  2. Open Developer Tools (F12)"
echo "  3. Clear cache (Ctrl+Shift+R)"
echo "  4. Try logging in"
echo ""
echo "Check logs if needed:"
echo "  sudo docker logs aml-frontend --tail 20"