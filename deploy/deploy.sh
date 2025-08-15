#!/bin/bash

# Main deployment script for AML Monitoring System
# This script orchestrates the entire deployment process

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
}

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

print_header "AML Monitoring System - Complete Deployment"

# Step 1: Run basic setup
print_header "Step 1: Running Basic Setup"
chmod +x setup.sh
./setup.sh

# Step 2: Configure Nginx
print_header "Step 2: Configuring Nginx"
chmod +x configure_nginx.sh
./configure_nginx.sh

# Step 3: Configure systemd service
print_header "Step 3: Setting up Systemd Service"
chmod +x configure_systemd.sh
./configure_systemd.sh

# Step 4: Set up monitoring
print_header "Step 4: Setting up Monitoring"
chmod +x setup_monitoring.sh
./setup_monitoring.sh

# Step 5: Run health check
print_header "Step 5: Running Health Check"
chmod +x health_check.sh
./health_check.sh

print_header "Deployment Complete!"
echo ""
echo "Your AML Monitoring System is now deployed!"
echo ""
echo "Important information:"
echo "  - API Documentation: http://your-server/docs"
echo "  - Health Check: http://your-server/health"
echo "  - Log files: /var/log/aml-monitoring/"
echo ""
echo "Service management:"
echo "  - Start: systemctl start aml-monitoring"
echo "  - Stop: systemctl stop aml-monitoring"
echo "  - Status: systemctl status aml-monitoring"
echo "  - Logs: journalctl -u aml-monitoring -f"
echo ""
echo "Configuration file: /opt/aml-monitoring/.env"
echo ""
print_warning "Remember to update the .env file with your production settings!"