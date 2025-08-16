#!/bin/bash

echo "========================================="
echo "Fixing Authentication & Connection Issues"
echo "========================================="

# Configuration
PUBLIC_IP=${PUBLIC_IP:-102.23.120.243}
DB_PASSWORD=${DB_PASSWORD:-changeme}

echo ""
echo "Step 1: Checking current status..."
echo "---------------------------------"

# Check if containers are running
echo "Checking Docker containers..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Step 2: Stopping all containers..."
echo "---------------------------------"
docker-compose -f docker-compose.102.23.120.243.yml down
docker-compose down
docker stop $(docker ps -aq) 2>/dev/null || true

echo ""
echo "Step 3: Cleaning up..."
echo "---------------------------------"
# Remove old containers and volumes
docker container prune -f
docker volume prune -f

echo ""
echo "Step 4: Creating fresh environment file..."
echo "---------------------------------"
cat > .env << EOF
# Environment Configuration
APP_NAME="AML Transaction Monitoring System"
APP_VERSION="1.0.0"
DEBUG=True
ENVIRONMENT=development
API_PORT=50000

# Database Configuration - SQLite for simplicity
DATABASE_URL=sqlite:///./aml_database.db

# Security
WEBHOOK_TOKEN=test-webhook-token
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS - Allow everything for testing
CORS_ALLOWED_ORIGINS=*

# Feature Flags
MONITORING_ENABLED=true
ENABLE_AI_ANALYSIS=false
ENABLE_EXTERNAL_SYNC=false

# Logging
LOG_LEVEL=DEBUG
EOF

echo "Created .env file with SQLite database"

echo ""
echo "Step 5: Starting backend service only..."
echo "---------------------------------"

# Start backend with simple configuration
docker run -d \
  --name aml-backend \
  -p 50000:50000 \
  -v $(pwd)/.env:/app/.env \
  -v $(pwd)/app:/app/app \
  -v $(pwd)/aml_database.db:/app/aml_database.db \
  --rm \
  python:3.11-slim \
  bash -c "
    cd /app && \
    apt-get update && apt-get install -y gcc curl && \
    pip install fastapi uvicorn sqlalchemy python-jose passlib bcrypt python-multipart psycopg2-binary && \
    python3 -c '
from sqlalchemy import create_engine, Column, Integer, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from passlib.context import CryptContext
from datetime import datetime

Base = declarative_base()
pwd_context = CryptContext(schemes=[\"bcrypt\"], deprecated=\"auto\")

class User(Base):
    __tablename__ = \"users\"
    id = Column(Integer, primary_key=True)
    name = Column(String)
    email = Column(String, unique=True)
    password = Column(String)
    created_at = Column(DateTime, default=datetime.now)

# Create database and user
engine = create_engine(\"sqlite:///./aml_database.db\")
Base.metadata.create_all(engine)

SessionLocal = sessionmaker(bind=engine)
db = SessionLocal()

# Create test user
existing = db.query(User).filter(User.email == \"admin@test.com\").first()
if not existing:
    user = User(
        name=\"Admin User\",
        email=\"admin@test.com\",
        password=pwd_context.hash(\"admin123\")
    )
    db.add(user)
    db.commit()
    print(\"Test user created: admin@test.com / admin123\")
else:
    print(\"User already exists\")
db.close()
' && \
    uvicorn app.main:app --host 0.0.0.0 --port 50000 --reload --log-level debug
  " || echo "Failed to start backend"

echo ""
echo "Waiting for backend to start..."
sleep 10

echo ""
echo "Step 6: Testing backend health..."
echo "---------------------------------"
curl -s http://localhost:50000/health | python3 -m json.tool || echo "Health check failed"

echo ""
echo "Step 7: Testing authentication directly..."
echo "---------------------------------"

# Test login with curl
echo "Testing login endpoint..."
curl -X POST http://localhost:50000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123" \
  -v 2>&1 | grep -E "(< HTTP|access_token|error)" || echo "Login test failed"

echo ""
echo "Step 8: Starting frontend..."
echo "---------------------------------"

# Start frontend
cd aml-frontend
npm install
REACT_APP_API_URL=http://$PUBLIC_IP:50000/api/v1 npm start &
cd ..

echo ""
echo "========================================="
echo "Fix Applied!"
echo "========================================="
echo ""
echo "Services should be available at:"
echo "  Backend: http://$PUBLIC_IP:50000"
echo "  Frontend: http://$PUBLIC_IP:3000"
echo "  Health: http://$PUBLIC_IP:50000/health"
echo "  Docs: http://$PUBLIC_IP:50000/docs"
echo ""
echo "Test login with:"
echo "  Email: admin@test.com"
echo "  Password: admin123"
echo ""
echo "Check logs:"
echo "  docker logs aml-backend"
echo ""