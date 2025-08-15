#!/bin/bash

# Set up monitoring for AML Monitoring System

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

# Install monitoring tools
print_status "Installing monitoring tools..."
apt-get install -y prometheus-node-exporter

# Set up log rotation
print_status "Configuring log rotation..."
cat > /etc/logrotate.d/aml-monitoring <<EOF
/var/log/aml-monitoring/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 amlapp amlapp
    sharedscripts
    postrotate
        systemctl reload aml-monitoring
    endscript
}
EOF

# Create monitoring script
print_status "Creating monitoring script..."
cat > /opt/aml-monitoring/monitor.sh <<'EOF'
#!/bin/bash

# Health check and alerting script

API_URL="http://localhost:50000/health"
ALERT_EMAIL="admin@yourcompany.com"
LOG_FILE="/var/log/aml-monitoring/monitor.log"

# Function to send alert
send_alert() {
    local subject="$1"
    local message="$2"
    echo "$(date): $subject - $message" >> $LOG_FILE
    # Uncomment to enable email alerts
    # echo "$message" | mail -s "$subject" $ALERT_EMAIL
}

# Check API health
response=$(curl -s -o /dev/null -w "%{http_code}" $API_URL)

if [ "$response" != "200" ]; then
    send_alert "AML API Down" "API health check failed with status: $response"
    systemctl restart aml-monitoring
fi

# Check disk usage
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 80 ]; then
    send_alert "High Disk Usage" "Disk usage is at ${disk_usage}%"
fi

# Check memory usage
memory_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ "$memory_usage" -gt 80 ]; then
    send_alert "High Memory Usage" "Memory usage is at ${memory_usage}%"
fi

# Check database connection
python3 <<PYTHON
import psycopg2
import sys

try:
    conn = psycopg2.connect("postgresql://amluser:SecurePassword123!@localhost:50003/amldb")
    conn.close()
except Exception as e:
    print(f"Database connection failed: {e}")
    sys.exit(1)
PYTHON

if [ $? -ne 0 ]; then
    send_alert "Database Connection Failed" "Unable to connect to PostgreSQL"
fi
EOF

chmod +x /opt/aml-monitoring/monitor.sh
chown amlapp:amlapp /opt/aml-monitoring/monitor.sh

# Add monitoring to crontab
print_status "Setting up monitoring cron job..."
(crontab -l 2>/dev/null || true; echo "*/5 * * * * /opt/aml-monitoring/monitor.sh") | crontab -

# Create dashboard script
print_status "Creating status dashboard..."
cat > /usr/local/bin/aml-status <<'EOF'
#!/bin/bash

echo "======================================"
echo "AML Monitoring System Status Dashboard"
echo "======================================"
echo ""

# Service status
echo "Service Status:"
systemctl is-active aml-monitoring >/dev/null 2>&1 && echo "  ✓ API Service: Running" || echo "  ✗ API Service: Stopped"
systemctl is-active postgresql >/dev/null 2>&1 && echo "  ✓ Database: Running" || echo "  ✗ Database: Stopped"
systemctl is-active nginx >/dev/null 2>&1 && echo "  ✓ Web Server: Running" || echo "  ✗ Web Server: Stopped"

echo ""
echo "System Resources:"
echo "  CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "  Memory: $(free -h | awk 'NR==2 {printf "%.1f GB / %.1f GB (%.0f%%)\n", $3, $2, $3/$2*100}')"
echo "  Disk: $(df -h / | awk 'NR==2 {printf "%s / %s (%s)\n", $3, $2, $5}')"

echo ""
echo "API Health:"
response=$(curl -s http://localhost:50000/health 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "  ✓ Health check: OK"
    echo "  Response: $response" | head -1
else
    echo "  ✗ Health check: Failed"
fi

echo ""
echo "Recent Logs (last 5 errors):"
if [ -f /var/log/aml-monitoring/error.log ]; then
    tail -5 /var/log/aml-monitoring/error.log | sed 's/^/  /'
else
    echo "  No error log found"
fi

echo ""
echo "Database Statistics:"
sudo -u postgres psql -d amldb -c "SELECT 'Suspicious Cases' as type, COUNT(*) as count FROM suspicious_cases UNION SELECT 'Customer Profiles', COUNT(*) FROM customer_profiles UNION SELECT 'Watchlist Entries', COUNT(*) FROM watchlists;" 2>/dev/null | grep -E "Suspicious|Customer|Watchlist" | sed 's/^/  /'

echo ""
echo "======================================"
EOF

chmod +x /usr/local/bin/aml-status

print_status "Monitoring setup complete!"
echo ""
echo "Monitoring tools installed:"
echo "  - Health check runs every 5 minutes"
echo "  - Log rotation configured (30 days retention)"
echo "  - Status dashboard: run 'aml-status' command"
echo ""
print_warning "Remember to update alert email in /opt/aml-monitoring/monitor.sh"