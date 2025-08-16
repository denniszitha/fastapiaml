#!/bin/bash

echo "Deploying CORS fix..."

# Stop existing containers
docker-compose down

# Rebuild backend with new CORS settings
docker-compose build backend

# Start services
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Test health endpoint
echo "Testing health endpoint..."
curl -I http://localhost:50000/health

echo "Testing CORS headers..."
curl -I -X OPTIONS http://localhost:50000/api/v1/health \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Content-Type"

echo "Deployment complete!"
echo "Check logs with: docker-compose logs -f backend"