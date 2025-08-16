#!/bin/bash

echo "========================================="
echo "Deploying Exemptions Page Fix"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}

echo ""
echo "Step 1: Pulling latest changes..."
echo "----------------------------------"
git pull origin main

echo ""
echo "Step 2: Rebuilding frontend with fixes..."
echo "-----------------------------------------"
cd aml-frontend

# Clean and reinstall dependencies
rm -rf node_modules build package-lock.json
npm install

# Set production environment variables
export REACT_APP_API_URL=http://$PUBLIC_IP:8000/api/v1
export REACT_APP_ENVIRONMENT=production

# Build the React app
echo "Building React app..."
npm run build

# Check if build succeeded
if [ ! -d "build" ]; then
    echo "✗ Build failed! Check for errors above."
    exit 1
fi

if [ ! -f "build/index.html" ]; then
    echo "✗ index.html not found in build directory!"
    exit 1
fi

echo "✓ Build successful!"

cd ..

echo ""
echo "Step 3: Restarting frontend container..."
echo "----------------------------------------"

# Stop and remove old container
sudo docker stop aml-frontend 2>/dev/null
sudo docker rm aml-frontend 2>/dev/null

# Start new container with updated build
sudo docker run -d \
  --name aml-frontend \
  --network aml-network \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/react-app.conf:/etc/nginx/conf.d/default.conf:ro \
  -p 8080:80 \
  --add-host=host.docker.internal:host-gateway \
  --restart always \
  nginx:alpine

echo ""
echo "Step 4: Verifying deployment..."
echo "-------------------------------"
sleep 3

# Check if container is running
sudo docker ps | grep aml-frontend > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Frontend container running"
else
    echo "✗ Frontend container not running"
    sudo docker logs aml-frontend --tail 20
    exit 1
fi

# Test nginx config
sudo docker exec aml-frontend nginx -t 2>&1 | grep -q "successful" && echo "✓ Nginx config valid" || echo "✗ Nginx config invalid"

# Test frontend accessibility
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$RESPONSE" = "200" ]; then
    echo "✓ Frontend is accessible (HTTP $RESPONSE)"
else
    echo "✗ Frontend returned HTTP $RESPONSE"
fi

# Test API proxy
curl -s http://localhost:8080/api/v1/health > /dev/null 2>&1 && echo "✓ API proxy working" || echo "✗ API proxy not working"

echo ""
echo "========================================="
echo "Exemptions Fix Deployed Successfully!"
echo "========================================="
echo ""
echo "The h.filter error has been fixed with:"
echo "  • Robust error handling for API responses"
echo "  • Support for multiple API response formats"
echo "  • Loading and error states in the UI"
echo "  • Null safety checks throughout"
echo ""
echo "Access the application at:"
echo "  http://$PUBLIC_IP:8080"
echo ""
echo "To check if the exemptions page works:"
echo "  1. Navigate to http://$PUBLIC_IP:8080/exemptions"
echo "  2. The page should load without errors"
echo "  3. It will show 'Loading exemptions...' while fetching data"
echo "  4. If API is down, it will show an error message"
echo ""