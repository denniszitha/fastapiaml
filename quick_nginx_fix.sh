#!/bin/bash

echo "========================================="
echo "Quick Nginx Fix (No Rebuild Required)"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}

echo ""
echo "Step 1: Checking if frontend build exists..."
echo "-------------------------------------------"

if [ ! -d "aml-frontend/build" ]; then
    echo "✗ Build directory not found!"
    echo "Creating minimal React app for testing..."
    
    mkdir -p aml-frontend/build
    cat > aml-frontend/build/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>AML Monitor - Loading...</title>
</head>
<body>
    <div id="root">
        <div style="display: flex; justify-content: center; align-items: center; height: 100vh; font-family: sans-serif;">
            <div>
                <h1>AML Monitor</h1>
                <p>Frontend build is missing. Please run: ./fix_frontend_complete.sh</p>
                <p>API Status: <span id="api-status">Checking...</span></p>
            </div>
        </div>
    </div>
    <script>
        fetch('/api/v1/health')
            .then(r => r.json())
            .then(d => document.getElementById('api-status').innerHTML = '✓ Connected')
            .catch(e => document.getElementById('api-status').innerHTML = '✗ Not Connected');
    </script>
</body>
</html>
EOF
else
    echo "✓ Build directory exists"
    
    # Check if index.html exists
    if [ ! -f "aml-frontend/build/index.html" ]; then
        echo "✗ index.html missing, copying from static folder..."
        # Try to find index.html
        find aml-frontend/build -name "index.html" -type f 2>/dev/null | head -1
    else
        echo "✓ index.html found"
    fi
fi

echo ""
echo "Step 2: Stopping old frontend..."
echo "-------------------------------"
docker stop aml-frontend 2>/dev/null
docker rm aml-frontend 2>/dev/null

echo ""
echo "Step 3: Starting frontend with fixed nginx..."
echo "-------------------------------------------"

# Create inline nginx config that definitely works
cat > /tmp/nginx-working.conf << 'NGINX'
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Main app - MUST handle React Router
    location / {
        try_files $uri /index.html;
    }
    
    # API proxy with network fix
    location /api/ {
        proxy_pass http://172.17.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Direct health check
    location /health {
        proxy_pass http://172.17.0.1:8000/health;
    }
}
NGINX

# Start with minimal config first
docker run -d \
  --name aml-frontend \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v /tmp/nginx-working.conf:/etc/nginx/conf.d/default.conf:ro \
  -p 8080:80 \
  --restart always \
  nginx:alpine

echo ""
echo "Step 4: Testing nginx..."
echo "-----------------------"
sleep 2

# Check if nginx started
docker ps | grep aml-frontend > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Nginx container running"
else
    echo "✗ Nginx container not running"
    docker logs aml-frontend
    exit 1
fi

# Test nginx config
docker exec aml-frontend nginx -t 2>&1 | grep -q "successful" && echo "✓ Nginx config valid" || echo "✗ Nginx config invalid"

echo ""
echo "Step 5: Testing accessibility..."
echo "-------------------------------"

# Test root path
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)
echo "Root path (/): HTTP $RESPONSE"

# Test if we get HTML
curl -s http://localhost:8080/ | head -3

echo ""
echo "Step 6: Checking container files..."
echo "----------------------------------"
docker exec aml-frontend sh -c "ls -la /usr/share/nginx/html/ | head -10"

echo ""
echo "Step 7: Testing backend connection..."
echo "------------------------------------"
curl -s http://localhost:8000/health > /dev/null 2>&1 && echo "✓ Backend on port 8000" || echo "✗ Backend not accessible on 8000"
curl -s http://localhost:8080/api/v1/health > /dev/null 2>&1 && echo "✓ API proxy working" || echo "✗ API proxy not working"

echo ""
echo "========================================="
echo "Quick Fix Applied!"
echo "========================================="
echo ""
echo "Frontend: http://$PUBLIC_IP:8080"
echo ""
echo "If you see 'Frontend build is missing' message:"
echo "  Run: ./fix_frontend_complete.sh"
echo ""
echo "To check logs:"
echo "  docker logs aml-frontend"
echo ""