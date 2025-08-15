# Port Configuration Guide - AML Monitoring System

## Port Allocation (50000-50010)

The AML Monitoring System uses ports in the range 50000-50010 for all services:

| Port  | Service | Description |
|-------|---------|-------------|
| 50000 | FastAPI Application | Main API server (internal) |
| 50001 | Nginx HTTP | Public HTTP access |
| 50002 | Nginx HTTPS | Public HTTPS access (SSL) |
| 50003 | PostgreSQL | Database server |
| 50004 | Redis | Cache/Queue server (optional) |
| 50005 | Prometheus | Metrics collection (optional) |
| 50006 | Grafana | Monitoring dashboard (optional) |
| 50007 | ElasticSearch | Log aggregation (optional) |
| 50008 | Kibana | Log visualization (optional) |
| 50009 | RabbitMQ | Message queue (optional) |
| 50010 | Reserved | Future use |

## Quick Setup

### 1. Configure All Services
```bash
cd /opt/fastapi-aml-monitoring/deploy
./deploy.sh
```

This automatically configures:
- FastAPI on port 50000
- Nginx on ports 50001 (HTTP) and 50002 (HTTPS)
- PostgreSQL on port 50003
- Firewall rules for ports 50000-50010

### 2. Manual Port Configuration

#### FastAPI Application
Edit `.env`:
```bash
API_PORT=50000
```

#### PostgreSQL
```bash
# Run the configuration script
./configure_postgresql_port.sh

# Or manually edit /etc/postgresql/*/main/postgresql.conf
port = 50003
```

#### Nginx
The configuration automatically proxies:
- Port 50001 (HTTP) → Port 50000 (FastAPI)
- Port 50002 (HTTPS) → Port 50000 (FastAPI)

## Firewall Configuration

### Allow Port Range
```bash
# Ubuntu/Debian with UFW
ufw allow 50000:50010/tcp

# CentOS/RHEL with firewalld
firewall-cmd --permanent --add-port=50000-50010/tcp
firewall-cmd --reload
```

### Check Open Ports
```bash
# List listening ports
netstat -tuln | grep 500

# Check specific port
lsof -i :50000
```

## Testing Connectivity

### Local Testing
```bash
# Test API
curl http://localhost:50000/health

# Test via Nginx
curl http://localhost:50001/health

# Test database
psql -h localhost -p 50003 -U amluser -d amldb
```

### Remote Testing
```bash
# Test from another server
curl http://your-server-ip:50001/health

# Test SSL
curl https://your-server-ip:50002/health
```

## Docker Configuration

### docker-compose.yml
```yaml
services:
  app:
    ports:
      - "50000:50000"
  
  db:
    ports:
      - "50003:5432"
    environment:
      POSTGRES_PORT: 50003
  
  redis:
    ports:
      - "50004:6379"
```

### Run with Custom Ports
```bash
docker run -p 50000:50000 aml-monitoring
```

## Troubleshooting

### Port Already in Use
```bash
# Find process using port
lsof -i :50000
# or
netstat -tulpn | grep 50000

# Kill process
kill -9 <PID>
```

### PostgreSQL Not Accessible on 50003
```bash
# Check if PostgreSQL is listening
ss -tuln | grep 50003

# Check PostgreSQL config
grep "port" /etc/postgresql/*/main/postgresql.conf

# Restart PostgreSQL
systemctl restart postgresql
```

### Nginx Not Forwarding
```bash
# Test Nginx config
nginx -t

# Check upstream
curl -I http://127.0.0.1:50000/health

# Reload Nginx
systemctl reload nginx
```

## Security Considerations

1. **Internal vs External Ports**
   - Port 50000 (FastAPI) should only be accessible locally
   - Ports 50001-50002 (Nginx) can be public
   - Port 50003 (PostgreSQL) should be restricted

2. **Firewall Rules**
   ```bash
   # Allow only specific IPs to database
   ufw allow from 192.168.1.0/24 to any port 50003
   
   # Allow public access to web
   ufw allow 50001,50002/tcp
   ```

3. **SSL/TLS**
   - Always use port 50002 (HTTPS) for production
   - Redirect port 50001 to 50002 after SSL setup

## Environment Variables

Add to `.env`:
```bash
# Port Configuration
API_PORT=50000
DATABASE_URL=postgresql://user:pass@localhost:50003/amldb
REDIS_URL=redis://localhost:50004/0

# Public Access
PUBLIC_HTTP_PORT=50001
PUBLIC_HTTPS_PORT=50002
```

## Monitoring Ports

Check all service statuses:
```bash
# Custom status script
/usr/local/bin/aml-status

# Manual checks
systemctl status aml-monitoring
netstat -tuln | grep -E '500[0-9]{2}'
```

## Load Balancing (Advanced)

For high availability, use multiple API instances:
```nginx
upstream aml_backends {
    server 127.0.0.1:50000;
    server 127.0.0.1:50011;  # Additional instance
    server 127.0.0.1:50012;  # Additional instance
}

server {
    listen 50001;
    location / {
        proxy_pass http://aml_backends;
    }
}
```

## Support

For port-related issues:
1. Check this guide
2. Run `./health_check.sh`
3. Check logs: `journalctl -u aml-monitoring -f`
4. Verify firewall: `ufw status numbered`