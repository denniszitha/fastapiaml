#!/bin/bash

echo "========================================="
echo "Frontend Port Fix Script"
echo "========================================="

PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}

echo ""
echo "Step 1: Stopping frontend container..."
echo "--------------------------------------"
docker stop aml-frontend 2>/dev/null
docker rm aml-frontend 2>/dev/null

echo ""
echo "Step 2: Updating frontend build with correct API URL..."
echo "-------------------------------------------------------"
cd aml-frontend

# Set production environment variables
export REACT_APP_API_URL=http://$PUBLIC_IP:8000/api/v1
export REACT_APP_ENVIRONMENT=production

echo "Building frontend with API URL: $REACT_APP_API_URL"

# Clean old build
rm -rf build

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build with correct API URL
npm run build

echo ""
echo "Step 3: Verifying build configuration..."
echo "----------------------------------------"
# Check if the API URL is correctly set in the build
grep -r "8000" build/static/js/*.js > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Frontend build contains correct port (8000)"
else
    echo "⚠ Warning: Port 8000 not found in build files"
    echo "Checking for old port 50000..."
    grep -r "50000" build/static/js/*.js > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✗ ERROR: Frontend still using port 50000!"
        echo "Manual intervention required"
    fi
fi

cd ..

echo ""
echo "Step 4: Starting frontend with new build..."
echo "------------------------------------------"
docker run -d \
  --name aml-frontend \
  --network aml-network \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro \
  -p 8080:80 \
  --restart always \
  nginx:alpine

echo ""
echo "Step 5: Testing frontend connectivity..."
echo "----------------------------------------"
sleep 3

# Test if frontend is accessible
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Frontend is accessible on port 8080"
else
    echo "✗ Frontend not accessible"
fi

echo ""
echo "Step 6: Verifying backend is running on port 8000..."
echo "----------------------------------------------------"
curl -s http://localhost:8000/health > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Backend is running on port 8000"
    curl -s http://localhost:8000/health | python3 -m json.tool
else
    echo "✗ Backend not accessible on port 8000"
    echo "Checking if backend is running..."
    docker ps | grep aml-backend
fi

echo ""
echo "Step 7: Test authentication flow..."
echo "-----------------------------------"
echo "Testing login endpoint directly:"
RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123")

if echo "$RESPONSE" | grep -q "access_token"; then
    echo "✓ Backend authentication working on port 8000"
else
    echo "✗ Authentication failed"
    echo "Response: $RESPONSE"
fi

echo ""
echo "========================================="
echo "Frontend Fix Complete!"
echo "========================================="
echo ""
echo "Services status:"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep "aml"
echo ""
echo "Access points:"
echo "  Frontend: http://$PUBLIC_IP:8080"
echo "  Backend API: http://$PUBLIC_IP:8000 (correct port)"
echo "  Old incorrect: http://$PUBLIC_IP:50000 (not used)"
echo ""
echo "The frontend should now connect to the backend on port 8000"
echo ""
echo "To verify in browser:"
echo "1. Open http://$PUBLIC_IP:8080"
echo "2. Open Developer Tools (F12)"
echo "3. Go to Network tab"
echo "4. Try to login"
echo "5. Check that API calls go to port 8000, not 50000"
echo ""