#!/bin/bash

# Update script for AML Monitoring System
# Use this to deploy new versions without full reinstall

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_DIR="/opt/aml-monitoring"
APP_USER="amlapp"
BACKUP_DIR="/opt/aml-monitoring-backups"

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

# Create backup
print_status "Creating backup..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
cp -r $APP_DIR $BACKUP_DIR/backup_$TIMESTAMP

# Stop services
print_status "Stopping services..."
systemctl stop aml-monitoring

# Update code
print_status "Updating application code..."
cp -r ../app/* $APP_DIR/app/
cp ../requirements.txt $APP_DIR/

# Update dependencies
print_status "Updating dependencies..."
cd $APP_DIR
sudo -u $APP_USER ./venv/bin/pip install -r requirements.txt

# Run database migrations if needed
print_status "Checking database..."
sudo -u $APP_USER ./venv/bin/python -c "
from app.db.base import engine, Base
Base.metadata.create_all(bind=engine)
print('Database updated')
"

# Restart services
print_status "Starting services..."
systemctl start aml-monitoring

# Wait for service to start
sleep 3

# Check if service is running
if systemctl is-active --quiet aml-monitoring; then
    print_status "Update completed successfully!"
    
    # Run health check
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:50000/health)
    if [ "$response" == "200" ]; then
        print_status "Health check passed!"
    else
        print_warning "Health check returned status: $response"
    fi
else
    print_error "Service failed to start!"
    print_warning "Rolling back..."
    
    # Rollback
    rm -rf $APP_DIR
    cp -r $BACKUP_DIR/backup_$TIMESTAMP $APP_DIR
    systemctl start aml-monitoring
    
    print_error "Update failed! Rolled back to previous version."
    exit 1
fi

echo ""
echo "Update completed at $(date)"
echo "Backup saved at: $BACKUP_DIR/backup_$TIMESTAMP"