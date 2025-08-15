# AML Monitoring System - Server Deployment Guide

## Prerequisites
- Ubuntu 20.04/22.04 or Debian 11/12 server
- Root or sudo access
- At least 2GB RAM
- 20GB disk space
- Domain name (optional, for SSL)

## Quick Deployment

### 1. Upload Files to Server
```bash
# From your local machine
scp -r fastapi-aml-monitoring/ root@your-server-ip:/tmp/
```

### 2. Connect to Server and Deploy
```bash
# SSH into server
ssh root@your-server-ip

# Move files to proper location
mv /tmp/fastapi-aml-monitoring /opt/
cd /opt/fastapi-aml-monitoring/deploy

# Make scripts executable
chmod +x *.sh

# Run complete deployment
./deploy.sh
```

## Step-by-Step Deployment

### 1. Initial Server Setup
```bash
cd /opt/fastapi-aml-monitoring/deploy
./setup.sh
```
This will:
- Install Python 3.11, PostgreSQL, Nginx
- Create application user
- Set up virtual environment
- Install dependencies
- Create database

### 2. Configure Nginx
```bash
./configure_nginx.sh
```
Enter your domain name when prompted (or use IP address)

### 3. Set up Auto-start Service
```bash
./configure_systemd.sh
```

### 4. Set up Monitoring
```bash
./setup_monitoring.sh
```

### 5. Configure Production Settings
```bash
# Edit production environment
nano /opt/aml-monitoring/.env

# Update these critical settings:
# - DATABASE_URL (with strong password)
# - WEBHOOK_TOKEN (generate new: openssl rand -hex 32)
# - SECRET_KEY (generate new: openssl rand -hex 32)
# - EXTERNAL_API_URL (your actual API endpoint)
```

## Post-Deployment

### 1. Verify Installation
```bash
# Run health check
./health_check.sh

# Check service status
systemctl status aml-monitoring

# View dashboard
aml-status
```

### 2. Test API
```bash
# Test health endpoint (on port 50001 for HTTP or 50002 for HTTPS)
curl http://your-server:50001/health

# View API docs
# Open in browser: http://your-server:50001/docs
```

### 3. Configure SSL (Recommended)
```bash
# Install SSL certificate
certbot --nginx -d your-domain.com

# Enable auto-renewal
certbot renew --dry-run
```

## Management Commands

### Service Control
```bash
# Start service
systemctl start aml-monitoring

# Stop service
systemctl stop aml-monitoring

# Restart service
systemctl restart aml-monitoring

# View status
systemctl status aml-monitoring
```

### Monitoring
```bash
# View logs
journalctl -u aml-monitoring -f

# Check application logs
tail -f /var/log/aml-monitoring/error.log

# View system status
aml-status
```

### Updates
```bash
# Deploy updates
cd /opt/fastapi-aml-monitoring/deploy
./update.sh
```

## Security Checklist

- [ ] Change default database password
- [ ] Generate new WEBHOOK_TOKEN
- [ ] Generate new SECRET_KEY
- [ ] Configure firewall (ufw)
- [ ] Enable SSL certificate
- [ ] Set up regular backups
- [ ] Configure log rotation
- [ ] Set up monitoring alerts
- [ ] Restrict SSH access
- [ ] Keep system updated

## Troubleshooting

### Service Won't Start
```bash
# Check logs
journalctl -u aml-monitoring -n 50

# Check syntax
/opt/aml-monitoring/venv/bin/python -m py_compile /opt/aml-monitoring/app/main.py

# Test database connection
sudo -u postgres psql -d amldb
```

### Database Issues
```bash
# Reset database
sudo -u postgres psql
DROP DATABASE amldb;
CREATE DATABASE amldb OWNER amluser;
\q

# Recreate tables
cd /opt/aml-monitoring
./venv/bin/python -c "from app.db.base import engine, Base; Base.metadata.create_all(bind=engine)"
```

### Port Already in Use
```bash
# Find process using port 50000
lsof -i :50000

# Kill process
kill -9 <PID>
```

## Performance Tuning

### 1. Increase Workers
Edit `/etc/systemd/system/aml-monitoring.service`:
```bash
--workers 8  # Increase based on CPU cores
```

### 2. Database Connection Pool
Edit `/opt/aml-monitoring/.env`:
```bash
DB_POOL_SIZE=50
DB_MAX_OVERFLOW=100
```

### 3. Enable Redis Caching
```bash
# Install Redis
apt-get install redis-server

# Update .env
REDIS_URL=redis://localhost:6379/0
```

## Backup and Recovery

### Create Backup
```bash
# Database backup
pg_dump -U amluser amldb > backup_$(date +%Y%m%d).sql

# Application backup
tar -czf aml_backup_$(date +%Y%m%d).tar.gz /opt/aml-monitoring
```

### Restore Backup
```bash
# Database restore
psql -U amluser amldb < backup_20240101.sql

# Application restore
tar -xzf aml_backup_20240101.tar.gz -C /
```

## Monitoring Integration

### Prometheus Metrics
```bash
# Add to .env
PROMETHEUS_ENABLED=true

# Access metrics at
http://your-server:50001/metrics
```

### Email Alerts
Edit `/opt/aml-monitoring/monitor.sh`:
- Update ALERT_EMAIL
- Configure SMTP settings

## Support

For issues:
1. Check logs: `journalctl -u aml-monitoring -f`
2. Run health check: `./health_check.sh`
3. Review this guide
4. Check API docs at `/docs`

## License
[Your License]