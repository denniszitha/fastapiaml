#!/bin/bash

echo "========================================="
echo "Simple Deployment Fix for 102.23.120.243"
echo "========================================="

PUBLIC_IP=102.23.120.243

# Step 1: Stop everything
echo "Stopping all containers..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Step 2: Use the standalone backend
echo "Starting standalone backend..."
docker build -f Dockerfile.simple -t aml-backend-simple .

docker run -d \
  --name aml-backend \
  -p 50000:50000 \
  -e CORS_ALLOWED_ORIGINS="*" \
  --restart always \
  aml-backend-simple

# Wait for backend
echo "Waiting for backend to start..."
sleep 5

# Step 3: Test backend
echo "Testing backend..."
curl -s http://localhost:50000/health | python3 -m json.tool

# Step 4: Test authentication
echo "Testing authentication..."
python3 test_auth.py http://localhost:50000

# Step 5: Build and start frontend
echo "Building frontend..."
cd aml-frontend

# Update API URL in build
cat > .env.production.local << EOF
REACT_APP_API_URL=http://$PUBLIC_IP:50000/api/v1
EOF

npm install
npm run build

# Serve with simple HTTP server
echo "Starting frontend..."
npx serve -s build -l 3000 &

cd ..

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Access the application:"
echo "  Frontend: http://$PUBLIC_IP:3000"
echo "  Backend: http://$PUBLIC_IP:50000"
echo "  API Docs: http://$PUBLIC_IP:50000/docs"
echo ""
echo "Login credentials:"
echo "  Email: admin@test.com"
echo "  Password: admin123"
echo ""
echo "To check status:"
echo "  docker logs aml-backend"
echo "  curl http://$PUBLIC_IP:50000/health"
echo ""