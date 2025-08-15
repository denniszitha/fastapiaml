#!/bin/bash

# Configure systemd service for AML Monitoring System

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Install Gunicorn
print_status "Installing Gunicorn..."
/opt/aml-monitoring/venv/bin/pip install gunicorn

# Create run directory
print_status "Creating run directory..."
mkdir -p /run/aml-monitoring
chown amlapp:amlapp /run/aml-monitoring

# Copy systemd service file
print_status "Installing systemd service..."
cp aml-monitoring.service /etc/systemd/system/

# Reload systemd
print_status "Reloading systemd daemon..."
systemctl daemon-reload

# Enable service
print_status "Enabling AML Monitoring service..."
systemctl enable aml-monitoring.service

# Start service
print_status "Starting AML Monitoring service..."
systemctl start aml-monitoring.service

# Check status
sleep 2
if systemctl is-active --quiet aml-monitoring.service; then
    print_status "AML Monitoring service is running!"
else
    print_error "Service failed to start. Check logs with: journalctl -u aml-monitoring.service"
fi

echo ""
echo "Service management commands:"
echo "  Start:   systemctl start aml-monitoring"
echo "  Stop:    systemctl stop aml-monitoring"
echo "  Restart: systemctl restart aml-monitoring"
echo "  Status:  systemctl status aml-monitoring"
echo "  Logs:    journalctl -u aml-monitoring -f"