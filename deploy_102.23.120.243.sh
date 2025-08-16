#!/bin/bash

echo "========================================="
echo "Deploying to 102.23.120.243"
echo "========================================="

# Set environment
export PUBLIC_IP=102.23.120.243
export DB_PASSWORD=${DB_PASSWORD:-changeme}

# Stop existing containers
echo "Stopping existing containers..."
docker-compose -f docker-compose.102.23.120.243.yml down

# Build images
echo "Building Docker images..."
docker-compose -f docker-compose.102.23.120.243.yml build

# Start services
echo "Starting services..."
docker-compose -f docker-compose.102.23.120.243.yml up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 15

# Create test user
echo "Creating test user..."
docker-compose -f docker-compose.102.23.120.243.yml exec backend python3 -c "
from sqlalchemy.orm import Session
from app.db.base import engine, Base
from app.models.user import User
from app.core.security import get_password_hash

Base.metadata.create_all(bind=engine)
db = Session(bind=engine)

try:
    existing = db.query(User).filter(User.email == 'admin@test.com').first()
    if not existing:
        user = User(
            name='Admin User',
            email='admin@test.com',
            password=get_password_hash('admin123')
        )
        db.add(user)
        db.commit()
        print('Test user created: admin@test.com / admin123')
    else:
        print('Test user already exists')
except Exception as e:
    print(f'Error: {e}')
finally:
    db.close()
" || echo "Could not create test user - create manually later"

# Test endpoints
echo ""
echo "Testing endpoints..."
echo "-------------------"

# Test health
echo "Testing health endpoint..."
curl -s http://$PUBLIC_IP:50000/health | python3 -m json.tool || echo "Health check failed"

# Test CORS
echo ""
echo "Testing CORS headers..."
curl -I -X OPTIONS http://$PUBLIC_IP:50000/api/v1/health \
  -H "Origin: http://$PUBLIC_IP:3000" \
  -H "Access-Control-Request-Method: GET" 2>/dev/null | grep -i "access-control" || echo "No CORS headers found"

echo ""
echo "========================================="
echo "Deployment complete!"
echo "========================================="
echo ""
echo "Access the application at:"
echo "  Frontend: http://$PUBLIC_IP:3000"
echo "  Backend API: http://$PUBLIC_IP:50000"
echo "  API Docs: http://$PUBLIC_IP:50000/docs"
echo ""
echo "Default credentials:"
echo "  Email: admin@test.com"
echo "  Password: admin123"
echo ""
echo "Check logs with:"
echo "  docker-compose -f docker-compose.102.23.120.243.yml logs -f"
echo ""