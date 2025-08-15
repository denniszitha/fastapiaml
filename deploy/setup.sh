#!/bin/bash

# FastAPI AML Monitoring System - Server Deployment Script
# This script sets up the application on Ubuntu/Debian servers

set -e

echo "========================================="
echo "FastAPI AML Monitoring System Deployment"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/opt/aml-monitoring"
APP_USER="amlapp"
PYTHON_VERSION="3.11"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Step 1: Update system packages
print_status "Updating system packages..."
apt-get update
apt-get upgrade -y

# Step 2: Install required system dependencies
print_status "Installing system dependencies..."
apt-get install -y \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    postgresql \
    postgresql-contrib \
    nginx \
    supervisor \
    git \
    ufw \
    certbot \
    python3-certbot-nginx \
    htop \
    build-essential \
    libpq-dev

# Step 3: Create application user
print_status "Creating application user..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -m -s /bin/bash $APP_USER
    print_status "User $APP_USER created"
else
    print_warning "User $APP_USER already exists"
fi

# Step 4: Create application directory
print_status "Setting up application directory..."
mkdir -p $APP_DIR
chown -R $APP_USER:$APP_USER $APP_DIR

# Step 5: Copy application files
print_status "Copying application files..."
cp -r ../app $APP_DIR/
cp ../requirements.txt $APP_DIR/
cp ../.env.example $APP_DIR/.env

# Step 6: Set up Python virtual environment
print_status "Setting up Python virtual environment..."
cd $APP_DIR
sudo -u $APP_USER python${PYTHON_VERSION} -m venv venv
sudo -u $APP_USER ./venv/bin/pip install --upgrade pip
sudo -u $APP_USER ./venv/bin/pip install -r requirements.txt

# Step 7: Configure PostgreSQL
print_status "Configuring PostgreSQL..."
sudo -u postgres psql <<EOF
CREATE USER amluser WITH PASSWORD 'SecurePassword123!';
CREATE DATABASE amldb OWNER amluser;
GRANT ALL PRIVILEGES ON DATABASE amldb TO amluser;
EOF

# Step 8: Configure environment variables
print_status "Configuring environment variables..."
cat > $APP_DIR/.env <<EOF
# Production Configuration
APP_NAME="AML Transaction Monitoring System"
APP_VERSION="1.0.0"
DEBUG=False

# Database
DATABASE_URL=postgresql://amluser:SecurePassword123!@localhost:50003/amldb
API_PORT=50000

# Security
WEBHOOK_TOKEN=$(openssl rand -hex 32)
SECRET_KEY=$(openssl rand -hex 32)
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# External API
EXTERNAL_API_URL=http://10.139.14.99:8000/process_json

# Features
MONITORING_ENABLED=true
ENABLE_AI_ANALYSIS=false
ENABLE_EXTERNAL_SYNC=false

# Logging
LOG_LEVEL=INFO
EOF

chown $APP_USER:$APP_USER $APP_DIR/.env
chmod 600 $APP_DIR/.env

# Step 9: Initialize database
print_status "Initializing database..."
cd $APP_DIR
sudo -u $APP_USER ./venv/bin/python -c "
from app.db.base import engine, Base
Base.metadata.create_all(bind=engine)
print('Database tables created successfully')
"

# Step 10: Configure firewall
print_status "Configuring firewall..."
ufw --force enable
ufw allow 22/tcp
# Allow ports 50000-50010 range for AML services
ufw allow 50000:50010/tcp

# Step 11: Set up log directory
print_status "Setting up logging..."
mkdir -p /var/log/aml-monitoring
chown -R $APP_USER:$APP_USER /var/log/aml-monitoring

print_status "Basic setup complete!"
echo ""
echo "Next steps:"
echo "1. Run: ./configure_nginx.sh to set up Nginx"
echo "2. Run: ./configure_supervisor.sh to set up process management"
echo "3. Update the .env file at $APP_DIR/.env with your settings"
echo "4. Run: ./start_services.sh to start the application"