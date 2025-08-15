#!/bin/bash

# Configure PostgreSQL to use custom port 50003

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

# Detect PostgreSQL version
PG_VERSION=$(sudo -u postgres psql --version | awk '{print $3}' | sed 's/\..*//')

if [ -z "$PG_VERSION" ]; then
    print_error "PostgreSQL not found"
    exit 1
fi

print_status "Found PostgreSQL version $PG_VERSION"

# Backup current configuration
print_status "Backing up PostgreSQL configuration..."
cp /etc/postgresql/$PG_VERSION/main/postgresql.conf /etc/postgresql/$PG_VERSION/main/postgresql.conf.backup

# Update PostgreSQL port
print_status "Updating PostgreSQL port to 50003..."
sed -i "s/^port = .*/port = 50003/" /etc/postgresql/$PG_VERSION/main/postgresql.conf

# If port line doesn't exist, add it
if ! grep -q "^port = " /etc/postgresql/$PG_VERSION/main/postgresql.conf; then
    echo "port = 50003" >> /etc/postgresql/$PG_VERSION/main/postgresql.conf
fi

# Update pg_hba.conf to ensure local connections work
print_status "Updating pg_hba.conf..."
if ! grep -q "host    amldb" /etc/postgresql/$PG_VERSION/main/pg_hba.conf; then
    echo "host    amldb           amluser         127.0.0.1/32            md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf
fi

# Restart PostgreSQL
print_status "Restarting PostgreSQL..."
systemctl restart postgresql

# Wait for PostgreSQL to start
sleep 3

# Test connection on new port
print_status "Testing PostgreSQL on port 50003..."
if sudo -u postgres psql -p 50003 -c "SELECT 1;" > /dev/null 2>&1; then
    print_status "PostgreSQL is running on port 50003"
else
    print_error "Failed to connect to PostgreSQL on port 50003"
    print_warning "Restoring original configuration..."
    cp /etc/postgresql/$PG_VERSION/main/postgresql.conf.backup /etc/postgresql/$PG_VERSION/main/postgresql.conf
    systemctl restart postgresql
    exit 1
fi

# Update systemd service if needed
if [ -f /lib/systemd/system/postgresql.service ]; then
    print_status "Updating systemd service..."
    systemctl daemon-reload
fi

print_status "PostgreSQL configuration complete!"
echo ""
echo "PostgreSQL is now running on port 50003"
echo "Connection string: postgresql://username:password@localhost:50003/database"
echo ""
print_warning "Remember to update your application's DATABASE_URL to use port 50003"