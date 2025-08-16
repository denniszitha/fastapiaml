#!/bin/bash

# ============================================
# QUICK FRONTEND FIX
# ============================================
# Rapidly deploys frontend when backend is already running
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PUBLIC_IP=${PUBLIC_IP:-$(curl -s http://checkip.amazonaws.com || echo "localhost")}
FRONTEND_PORT=8888
BACKEND_PORT=8000

echo -e "${GREEN}QUICK FRONTEND FIX${NC}"
echo "=================="
echo ""

# Stop old frontend
echo "1. Stopping old frontend..."
sudo docker stop aml-frontend 2>/dev/null || true
sudo docker rm aml-frontend 2>/dev/null || true

# Check for existing build
if [ -d "aml-frontend/build" ] && [ -f "aml-frontend/build/index.html" ]; then
    echo "2. Using existing build..."
else
    echo "2. Creating minimal build..."
    mkdir -p aml-frontend/build
    
    # Create a working minimal React app
    cat > aml-frontend/build/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AML Monitor</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <div id="root">
        <nav class="navbar navbar-dark bg-dark">
            <div class="container-fluid">
                <span class="navbar-brand mb-0 h1">AML Monitoring System</span>
            </div>
        </nav>
        <div class="container mt-5">
            <div class="row">
                <div class="col-md-12">
                    <div class="card">
                        <div class="card-body">
                            <h5 class="card-title">System Status</h5>
                            <p>Backend API: <span id="api-status" class="badge bg-secondary">Checking...</span></p>
                            <p>Database: <span id="db-status" class="badge bg-secondary">Checking...</span></p>
                            <hr>
                            <div class="d-grid gap-2">
                                <a href="/api/v1/docs" target="_blank" class="btn btn-primary">API Documentation</a>
                                <button onclick="testAPI()" class="btn btn-secondary">Test API Connection</button>
                            </div>
                        </div>
                    </div>
                    
                    <div class="card mt-3">
                        <div class="card-body">
                            <h5 class="card-title">Quick Actions</h5>
                            <p>The full React application needs to be built. Use one of these options:</p>
                            <ol>
                                <li>Run: <code>./complete_frontend_deployment.sh</code> to build the full frontend</li>
                                <li>Access the API directly at: <code>http://EOF
    echo "$PUBLIC_IP:$BACKEND_PORT</code></li>" >> aml-frontend/build/index.html
    cat >> aml-frontend/build/index.html << 'EOF'
                            </ol>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <script>
        function checkAPI() {
            fetch('/api/v1/health')
                .then(r => r.json())
                .then(d => {
                    document.getElementById('api-status').className = 'badge bg-success';
                    document.getElementById('api-status').innerText = 'Connected';
                    document.getElementById('db-status').className = 'badge bg-success';
                    document.getElementById('db-status').innerText = 'Connected';
                })
                .catch(e => {
                    document.getElementById('api-status').className = 'badge bg-danger';
                    document.getElementById('api-status').innerText = 'Error';
                    console.error('API Error:', e);
                });
        }
        
        function testAPI() {
            fetch('/api/v1/statistics/dashboard')
                .then(r => r.json())
                .then(d => {
                    alert('API Test Successful!\n\nDashboard stats received:\n' + JSON.stringify(d, null, 2).substring(0, 200) + '...');
                })
                .catch(e => alert('API Test Failed:\n' + e.message));
        }
        
        // Check API on load
        checkAPI();
        setInterval(checkAPI, 5000);
    </script>
</body>
</html>
EOF
fi

# Create simple nginx config
echo "3. Creating nginx config..."
mkdir -p nginx
cat > nginx/simple.conf << EOF
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # Multiple API proxy attempts
    location /api/ {
        proxy_pass http://172.17.0.1:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        
        # Backup using host.docker.internal
        error_page 502 = @backup;
    }
    
    location @backup {
        proxy_pass http://host.docker.internal:$BACKEND_PORT\$request_uri;
        proxy_http_version 1.1;
    }
    
    location /health {
        proxy_pass http://172.17.0.1:$BACKEND_PORT/health;
    }
}
EOF

# Start frontend
echo "4. Starting frontend container..."
sudo docker run -d \
  --name aml-frontend \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/simple.conf:/etc/nginx/conf.d/default.conf:ro \
  -p $FRONTEND_PORT:80 \
  --add-host=host.docker.internal:host-gateway \
  --restart always \
  nginx:alpine

# Try to connect to network
sudo docker network connect aml-network aml-frontend 2>/dev/null || true

sleep 3

# Test
echo ""
echo "5. Testing..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT)
if [ "$STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Frontend is running on port $FRONTEND_PORT${NC}"
else
    echo -e "${RED}✗ Frontend returned HTTP $STATUS${NC}"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo "Access: http://$PUBLIC_IP:$FRONTEND_PORT"
echo ""
echo "To build the full React app later, run:"
echo "  ./complete_frontend_deployment.sh"