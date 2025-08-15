#!/bin/bash

# Health check script for AML Monitoring System

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

echo "Running health checks..."
echo ""

# Check if services are running
echo "Checking services..."

# PostgreSQL
if systemctl is-active --quiet postgresql; then
    print_status "PostgreSQL is running"
else
    print_error "PostgreSQL is not running"
fi

# Nginx
if systemctl is-active --quiet nginx; then
    print_status "Nginx is running"
else
    print_error "Nginx is not running"
fi

# AML Monitoring Service
if systemctl is-active --quiet aml-monitoring; then
    print_status "AML Monitoring service is running"
else
    print_error "AML Monitoring service is not running"
fi

echo ""
echo "Checking API endpoints..."

# Check health endpoint
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:50000/health)
if [ "$response" == "200" ]; then
    print_status "Health endpoint responding (HTTP $response)"
else
    print_error "Health endpoint not responding (HTTP $response)"
fi

# Check API docs
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:50000/docs)
if [ "$response" == "200" ]; then
    print_status "API documentation available (HTTP $response)"
else
    print_warning "API documentation not accessible (HTTP $response)"
fi

echo ""
echo "Checking database connectivity..."

# Test database connection
sudo -u postgres psql -d amldb -c "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_status "Database connection successful"
    
    # Count tables
    table_count=$(sudo -u postgres psql -d amldb -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
    echo "  - Tables in database: $table_count"
else
    print_error "Database connection failed"
fi

echo ""
echo "Checking disk space..."
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_usage" -lt 80 ]; then
    print_status "Disk usage is healthy (${disk_usage}%)"
else
    print_warning "Disk usage is high (${disk_usage}%)"
fi

echo ""
echo "Checking memory..."
memory_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ "$memory_usage" -lt 80 ]; then
    print_status "Memory usage is healthy (${memory_usage}%)"
else
    print_warning "Memory usage is high (${memory_usage}%)"
fi

echo ""
echo "Checking logs for errors..."
if [ -f /var/log/aml-monitoring/error.log ]; then
    error_count=$(tail -100 /var/log/aml-monitoring/error.log 2>/dev/null | grep -c ERROR || true)
    if [ "$error_count" -eq 0 ]; then
        print_status "No recent errors in logs"
    else
        print_warning "Found $error_count errors in recent logs"
    fi
else
    print_warning "Error log not found"
fi

echo ""
echo "Health check complete!"