#!/bin/bash

echo "========================================="
echo "Complete Frontend Fix Script"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}

echo ""
echo "Step 1: Stopping frontend container..."
echo "--------------------------------------"
docker stop aml-frontend 2>/dev/null
docker rm aml-frontend 2>/dev/null

echo ""
echo "Step 2: Building frontend with fixes..."
echo "---------------------------------------"
cd aml-frontend

# Clean node modules and build
echo "Cleaning old build..."
rm -rf node_modules build package-lock.json

echo "Installing dependencies..."
npm install

# Set production environment variables
export REACT_APP_API_URL=http://$PUBLIC_IP:8000/api/v1
export REACT_APP_ENVIRONMENT=production

echo "Building React app..."
npm run build

# Check if build succeeded
if [ ! -d "build" ]; then
    echo "✗ Build failed! Check for errors above."
    exit 1
fi

# Verify index.html exists
if [ ! -f "build/index.html" ]; then
    echo "✗ index.html not found in build directory!"
    exit 1
fi

echo "✓ Build successful!"
echo "Build contains:"
ls -la build/

cd ..

echo ""
echo "Step 3: Starting frontend with proper nginx config..."
echo "----------------------------------------------------"

# Use the fixed nginx configuration
docker run -d \
  --name aml-frontend \
  --network aml-network \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/react-app.conf:/etc/nginx/conf.d/default.conf:ro \
  -p 8080:80 \
  --add-host=host.docker.internal:host-gateway \
  --restart always \
  nginx:alpine

echo ""
echo "Step 4: Verifying nginx configuration..."
echo "----------------------------------------"
sleep 3

# Test nginx config inside container
docker exec aml-frontend nginx -t 2>&1

echo ""
echo "Step 5: Testing frontend accessibility..."
echo "----------------------------------------"

# Test if index.html is served
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$RESPONSE" = "200" ]; then
    echo "✓ Frontend is accessible (HTTP $RESPONSE)"
else
    echo "✗ Frontend returned HTTP $RESPONSE"
    echo "Checking nginx error logs:"
    docker logs aml-frontend --tail 20
fi

# Test if React app loads
curl -s http://localhost:8080 | grep -q "<div id=\"root\">" && echo "✓ React app HTML found" || echo "✗ React app HTML not found"

echo ""
echo "Step 6: Testing API proxy..."
echo "---------------------------"

# Test backend through nginx proxy
curl -s http://localhost:8080/api/v1/health > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ API proxy working"
else
    echo "✗ API proxy not working"
    echo "Testing backend directly..."
    curl -s http://localhost:8000/health > /dev/null 2>&1 && echo "  Backend is running on port 8000" || echo "  Backend not accessible"
fi

echo ""
echo "Step 7: Checking for common issues..."
echo "------------------------------------"

# Check if files are readable
docker exec aml-frontend ls -la /usr/share/nginx/html/ | head -5

# Check nginx processes
docker exec aml-frontend ps aux | grep nginx

echo ""
echo "========================================="
echo "Frontend Fix Complete!"
echo "========================================="
echo ""
echo "Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep aml-frontend
echo ""
echo "Access the application at:"
echo "  http://$PUBLIC_IP:8080"
echo ""
echo "If still having issues, check:"
echo "  docker logs aml-frontend"
echo "  docker exec aml-frontend cat /var/log/nginx/error.log"
echo ""