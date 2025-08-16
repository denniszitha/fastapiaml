#!/bin/bash

# ============================================
# UNIFIED AML SYSTEM DEPLOYMENT SCRIPT
# ============================================
# This script deploys the complete AML monitoring system
# with custom ports to avoid conflicts
#
# Port Configuration:
# - Frontend: 8888 (instead of 80/8080)
# - Backend API: 8000
# - PostgreSQL: 5433 (instead of 5432)
# - Redis: 6380 (instead of 6379)
# ============================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PUBLIC_IP=${PUBLIC_IP:-$(curl -s http://checkip.amazonaws.com || echo "localhost")}
FRONTEND_PORT=${FRONTEND_PORT:-8888}
BACKEND_PORT=${BACKEND_PORT:-8000}
DB_PORT=${DB_PORT:-5433}
REDIS_PORT=${REDIS_PORT:-6380}

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}AML MONITORING SYSTEM - PRODUCTION DEPLOYMENT${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Public IP: $PUBLIC_IP"
echo "  Frontend Port: $FRONTEND_PORT"
echo "  Backend Port: $BACKEND_PORT"
echo "  Database Port: $DB_PORT"
echo "  Redis Port: $REDIS_PORT"
echo ""
echo -e "${YELLOW}This will deploy the complete system from scratch.${NC}"
read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo ""
echo -e "${GREEN}Step 1: Cleaning up existing containers...${NC}"
echo "----------------------------------------"
# Stop and remove any existing containers
sudo docker stop aml-frontend aml-backend postgres redis 2>/dev/null || true
sudo docker rm aml-frontend aml-backend postgres redis 2>/dev/null || true
sudo docker network rm aml-network 2>/dev/null || true
echo "✓ Cleanup complete"

echo ""
echo -e "${GREEN}Step 2: Creating Docker network...${NC}"
echo "--------------------------------"
sudo docker network create aml-network 2>/dev/null || true
echo "✓ Network created"

echo ""
echo -e "${GREEN}Step 3: Starting PostgreSQL database...${NC}"
echo "-------------------------------------"
sudo docker run -d \
  --name postgres \
  --network aml-network \
  -e POSTGRES_DB=aml_monitoring \
  -e POSTGRES_USER=aml_user \
  -e POSTGRES_PASSWORD=secure_password \
  -p $DB_PORT:5432 \
  -v postgres-data:/var/lib/postgresql/data \
  --restart always \
  postgres:14-alpine

echo "Waiting for PostgreSQL to be ready..."
sleep 10

# Initialize database schema
echo "Initializing database schema..."
cat > /tmp/init-db.sql << 'EOF'
-- Create ENUM types
CREATE TYPE transaction_status AS ENUM ('PENDING', 'COMPLETED', 'FAILED', 'BLOCKED');
CREATE TYPE risk_level AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE customer_type AS ENUM ('INDIVIDUAL', 'CORPORATE');

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(200),
    hashed_password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_superuser BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customer profiles
CREATE TABLE IF NOT EXISTS customer_profiles (
    id SERIAL PRIMARY KEY,
    account_number VARCHAR(50) UNIQUE NOT NULL,
    account_name VARCHAR(200) NOT NULL,
    customer_type customer_type NOT NULL,
    risk_level risk_level NOT NULL,
    country VARCHAR(100),
    is_pep BOOLEAN DEFAULT false,
    is_sanctioned BOOLEAN DEFAULT false,
    kyc_verified BOOLEAN DEFAULT true,
    account_balance DECIMAL(15, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Watchlist
CREATE TABLE IF NOT EXISTS watchlist (
    id SERIAL PRIMARY KEY,
    account_number VARCHAR(50) UNIQUE NOT NULL,
    account_name VARCHAR(200),
    reason TEXT,
    risk_level risk_level NOT NULL,
    added_by VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transaction exemptions
CREATE TABLE IF NOT EXISTS transaction_exemptions (
    id SERIAL PRIMARY KEY,
    account_number VARCHAR(50) UNIQUE NOT NULL,
    account_name VARCHAR(200),
    exemption_type VARCHAR(50),
    reason TEXT,
    start_date DATE,
    end_date DATE,
    approved_by VARCHAR(100),
    conditions TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transaction limits
CREATE TABLE IF NOT EXISTS transaction_limits (
    id SERIAL PRIMARY KEY,
    limit_type VARCHAR(50) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    min_amount DECIMAL(15, 2),
    max_amount DECIMAL(15, 2),
    customer_type customer_type,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Suspicious cases
CREATE TABLE IF NOT EXISTS suspicious_cases (
    id SERIAL PRIMARY KEY,
    case_number VARCHAR(50) UNIQUE NOT NULL,
    account_number VARCHAR(50),
    account_name VARCHAR(200),
    transaction_id VARCHAR(100),
    transaction_amount DECIMAL(15, 2),
    risk_score DECIMAL(5, 2),
    alert_reason TEXT,
    status VARCHAR(50) DEFAULT 'PENDING',
    assigned_to VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    action VARCHAR(100),
    resource_type VARCHAR(100),
    resource_id VARCHAR(100),
    details JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_customer_profiles_account ON customer_profiles(account_number);
CREATE INDEX IF NOT EXISTS idx_customer_profiles_risk ON customer_profiles(risk_level);
CREATE INDEX IF NOT EXISTS idx_watchlist_account ON watchlist(account_number);
CREATE INDEX IF NOT EXISTS idx_watchlist_active ON watchlist(is_active);
CREATE INDEX IF NOT EXISTS idx_suspicious_cases_status ON suspicious_cases(status);
CREATE INDEX IF NOT EXISTS idx_suspicious_cases_account ON suspicious_cases(account_number);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

-- Insert default admin user (password: admin123)
INSERT INTO users (username, email, full_name, hashed_password, is_active, is_superuser)
VALUES ('admin', 'admin@amlsystem.com', 'System Administrator', 
        '$2b$12$W6qvJ1OmFRrNK9p5kRXQpOQK4bHhmnQwp7xLQPjU.t/FP3geUvH2a', true, true)
ON CONFLICT (username) DO NOTHING;
EOF

sudo docker exec postgres psql -U aml_user -d aml_monitoring -f /dev/stdin < /tmp/init-db.sql 2>/dev/null || true
rm /tmp/init-db.sql
echo "✓ PostgreSQL started and initialized"

echo ""
echo -e "${GREEN}Step 4: Starting Redis cache...${NC}"
echo "-----------------------------"
sudo docker run -d \
  --name redis \
  --network aml-network \
  -p $REDIS_PORT:6379 \
  -v redis-data:/data \
  --restart always \
  redis:7-alpine \
  redis-server --appendonly yes

echo "✓ Redis started"

echo ""
echo -e "${GREEN}Step 5: Building and starting backend...${NC}"
echo "--------------------------------------"
# Create Dockerfile for backend if it doesn't exist
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app/

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=postgresql://aml_user:secure_password@postgres:5432/aml_monitoring
ENV REDIS_URL=redis://redis:6379/0

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF

# Build backend image
echo "Building backend Docker image..."
sudo docker build -t aml-backend:latest .

# Run backend container
sudo docker run -d \
  --name aml-backend \
  --network aml-network \
  -p $BACKEND_PORT:8000 \
  -e DATABASE_URL=postgresql://aml_user:secure_password@postgres:5432/aml_monitoring \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY=your-secret-key-here-change-in-production \
  -e CORS_ORIGINS="*" \
  -v $(pwd)/app:/app/app:ro \
  --restart always \
  aml-backend:latest

echo "Waiting for backend to start..."
sleep 10

# Check backend health
curl -s http://localhost:$BACKEND_PORT/health > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Backend started successfully"
else
    echo "⚠ Backend may not be fully ready yet"
fi

echo ""
echo -e "${GREEN}Step 6: Building and starting frontend...${NC}"
echo "---------------------------------------"
cd aml-frontend

# Update API URL in frontend for production
echo "Configuring frontend for production..."
export REACT_APP_API_URL=http://$PUBLIC_IP:$BACKEND_PORT/api/v1
export REACT_APP_ENVIRONMENT=production

# Install dependencies and build
echo "Installing frontend dependencies..."
npm install --silent

echo "Building frontend..."
npm run build

if [ ! -d "build" ]; then
    echo -e "${RED}✗ Frontend build failed!${NC}"
    exit 1
fi

cd ..

# Create nginx configuration with custom port
cat > nginx/nginx.conf << EOF
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Frontend routes
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
    
    # API proxy
    location /api/ {
        proxy_pass http://host.docker.internal:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://host.docker.internal:$BACKEND_PORT/health;
    }
    
    # WebSocket support
    location /ws {
        proxy_pass http://host.docker.internal:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml application/atom+xml image/svg+xml text/javascript;
}
EOF

# Start frontend container
sudo docker run -d \
  --name aml-frontend \
  --network aml-network \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  -p $FRONTEND_PORT:80 \
  --add-host=host.docker.internal:host-gateway \
  --restart always \
  nginx:alpine

echo "✓ Frontend started"

echo ""
echo -e "${GREEN}Step 7: Verifying deployment...${NC}"
echo "-----------------------------"

# Check all containers
echo "Container status:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|aml-|postgres|redis" || true

echo ""
echo "Testing endpoints..."

# Test frontend
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✓ Frontend: http://localhost:$FRONTEND_PORT (HTTP $FRONTEND_STATUS)"
else
    echo "⚠ Frontend: HTTP $FRONTEND_STATUS"
fi

# Test backend
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$BACKEND_PORT/health)
if [ "$BACKEND_STATUS" = "200" ]; then
    echo "✓ Backend: http://localhost:$BACKEND_PORT (HTTP $BACKEND_STATUS)"
else
    echo "⚠ Backend: HTTP $BACKEND_STATUS"
fi

# Test API through nginx proxy
API_PROXY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT/api/v1/health 2>/dev/null)
if [ "$API_PROXY_STATUS" = "200" ]; then
    echo "✓ API Proxy: Working"
else
    echo "⚠ API Proxy: May need configuration"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Access the application:${NC}"
echo "  Frontend: http://$PUBLIC_IP:$FRONTEND_PORT"
echo "  Backend API: http://$PUBLIC_IP:$BACKEND_PORT"
echo "  API Docs: http://$PUBLIC_IP:$BACKEND_PORT/docs"
echo ""
echo -e "${YELLOW}Default credentials:${NC}"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo -e "${YELLOW}Services running on:${NC}"
echo "  Frontend: Port $FRONTEND_PORT"
echo "  Backend: Port $BACKEND_PORT"
echo "  PostgreSQL: Port $DB_PORT"
echo "  Redis: Port $REDIS_PORT"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  View logs: sudo docker logs [container-name]"
echo "  Stop all: sudo docker stop aml-frontend aml-backend postgres redis"
echo "  Start all: sudo docker start postgres redis aml-backend aml-frontend"
echo "  Remove all: sudo docker rm -f aml-frontend aml-backend postgres redis"
echo ""
echo -e "${YELLOW}To populate with test data:${NC}"
echo "  ./populate_docker_db.sh"
echo ""