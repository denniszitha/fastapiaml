#!/bin/bash

echo "========================================="
echo "Quick Frontend Fix (Without Rebuild)"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}

echo ""
echo "Step 1: Creating nginx config with proxy to correct port..."
echo "----------------------------------------------------------"

cat > /tmp/nginx-fixed.conf << 'EOF'
server {
    listen 80;
    server_name _;

    # Frontend files
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
        
        # Inject correct API URL into index.html
        sub_filter_once off;
        sub_filter 'http://102.23.120.243:50000' 'http://102.23.120.243:8000';
        sub_filter 'localhost:50000' 'localhost:8000';
        sub_filter ':50000/api' ':8000/api';
    }

    # Proxy API calls to backend on port 8000
    location /api/ {
        proxy_pass http://backend:50000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' '*' always;
    }

    # Health endpoint
    location /health {
        proxy_pass http://backend:50000/health;
    }

    # API docs
    location /docs {
        proxy_pass http://backend:50000/docs;
    }

    location /openapi.json {
        proxy_pass http://backend:50000/openapi.json;
    }
}
EOF

echo ""
echo "Step 2: Restarting frontend with fixed nginx config..."
echo "------------------------------------------------------"
docker stop aml-frontend 2>/dev/null
docker rm aml-frontend 2>/dev/null

docker run -d \
  --name aml-frontend \
  --network aml-network \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v /tmp/nginx-fixed.conf:/etc/nginx/conf.d/default.conf:ro \
  -p 8080:80 \
  --restart always \
  nginx:alpine

echo ""
echo "Step 3: Alternative - Update JavaScript files directly..."
echo "--------------------------------------------------------"
# This is a hack but works immediately without rebuild
docker exec aml-frontend sh -c "
cd /usr/share/nginx/html/static/js
for file in *.js; do
    if grep -q '50000' \$file 2>/dev/null; then
        echo 'Found port 50000 in \$file, replacing with 8000...'
        sed -i 's/:50000/:8000/g' \$file
    fi
done
"

echo ""
echo "Step 4: Verify fix..."
echo "--------------------"
sleep 2

echo "Testing backend on port 8000:"
curl -s http://localhost:8000/health > /dev/null 2>&1 && echo "✓ Backend accessible on port 8000" || echo "✗ Backend not accessible"

echo ""
echo "Testing frontend on port 8080:"
curl -s http://localhost:8080 > /dev/null 2>&1 && echo "✓ Frontend accessible on port 8080" || echo "✗ Frontend not accessible"

echo ""
echo "========================================="
echo "Quick Fix Applied!"
echo "========================================="
echo ""
echo "The frontend should now connect to port 8000"
echo ""
echo "Test by:"
echo "1. Open http://$PUBLIC_IP:8080"
echo "2. Try to login with admin@test.com / admin123"
echo "3. Check browser console for any errors"
echo ""
echo "If this doesn't work, run ./fix_frontend.sh for a full rebuild"
echo ""