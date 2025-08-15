#!/bin/bash

# Configure Nginx for AML Monitoring System

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

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Get domain name
read -p "Enter your domain name (e.g., aml.yourcompany.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    print_warning "No domain provided, using server IP configuration"
    DOMAIN_NAME=$(hostname -I | awk '{print $1}')
fi

# Copy Nginx configuration
print_status "Installing Nginx configuration..."
cp nginx.conf /etc/nginx/sites-available/aml-monitoring

# Update domain in configuration
sed -i "s/your-domain.com/$DOMAIN_NAME/g" /etc/nginx/sites-available/aml-monitoring

# Enable the site
ln -sf /etc/nginx/sites-available/aml-monitoring /etc/nginx/sites-enabled/

# Remove default site if exists
if [ -L /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi

# Test Nginx configuration
print_status "Testing Nginx configuration..."
nginx -t

# Reload Nginx
print_status "Reloading Nginx..."
systemctl reload nginx

# Set up SSL with Let's Encrypt (optional)
read -p "Do you want to set up SSL with Let's Encrypt? (y/n): " SETUP_SSL

if [ "$SETUP_SSL" = "y" ]; then
    read -p "Enter your email for SSL certificate: " EMAIL
    
    print_status "Setting up SSL certificate..."
    certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email $EMAIL
    
    # Set up auto-renewal
    print_status "Setting up SSL auto-renewal..."
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
fi

print_status "Nginx configuration complete!"
echo ""
echo "Your API is now accessible at:"
if [ "$SETUP_SSL" = "y" ]; then
    echo "  https://$DOMAIN_NAME"
else
    echo "  http://$DOMAIN_NAME"
fi