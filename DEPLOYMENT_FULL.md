# AML Monitoring System - Deployment Guide

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Git
- 4GB+ RAM
- 20GB+ disk space

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/denniszitha/fastapiaml.git
cd fastapiaml
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your production values
nano .env
```

**Important**: Update these values in production:
- `SECRET_KEY` - Generate a secure random key
- `POSTGRES_PASSWORD` - Use a strong database password
- `SMTP_*` - Configure email settings if needed

### 3. Build and Start Services

```bash
# Build all services
docker-compose build

# Start all services
docker-compose up -d

# Check service status
docker-compose ps
```

### 4. Initialize Database

```bash
# Run database migrations
docker-compose exec backend alembic upgrade head

# Create admin user (optional)
docker-compose exec backend python -m app.scripts.create_admin
```

## Architecture

The application consists of the following services:

- **Frontend** (React): User interface served via Nginx
- **Backend** (FastAPI): API server handling business logic
- **PostgreSQL**: Primary database for application data
- **Redis**: Caching and session storage
- **Nginx**: Reverse proxy and static file serving

## Service Configuration

### Database (PostgreSQL)

- Port: 5432 (internal)
- Data volume: `postgres_data`
- Health check: `pg_isready`
- Automatic restart: always

### Redis

- Port: 6379 (internal)
- Data volume: `redis_data`
- Health check: `redis-cli ping`

### Backend (FastAPI)

- Port: 8000 (internal)
- Workers: 4 (configurable)
- Health endpoint: `/health`
- API docs: `/docs`

### Frontend (React)

- Port: 80 (exposed)
- Nginx configuration included
- Static asset caching enabled
- SPA routing configured

## Production Deployment

### Using Docker Swarm

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml aml-stack

# Scale services
docker service scale aml-stack_backend=3
```

### Using Kubernetes

See `k8s/` directory for Kubernetes manifests (if available).

### SSL/TLS Configuration

1. Obtain SSL certificates (e.g., from Let's Encrypt)
2. Update `nginx/conf.d/default.conf`:
   - Uncomment HTTPS server block
   - Update certificate paths
   - Enable HTTP to HTTPS redirect

```nginx
ssl_certificate /etc/nginx/ssl/cert.pem;
ssl_certificate_key /etc/nginx/ssl/key.pem;
```

3. Mount certificates in docker-compose.yml:

```yaml
nginx:
  volumes:
    - ./ssl:/etc/nginx/ssl:ro
```

## Monitoring

### Health Checks

All services include health check endpoints:

```bash
# Check all service health
docker-compose ps

# Check specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend
```

### Application Logs

Logs are stored in:
- Backend: `/app/logs/` (inside container)
- Nginx: `/var/log/nginx/`

To access logs:

```bash
# Backend logs
docker-compose logs -f backend

# Nginx access logs
docker-compose exec nginx tail -f /var/log/nginx/access.log

# Nginx error logs
docker-compose exec nginx tail -f /var/log/nginx/error.log
```

## Backup and Recovery

### Database Backup

```bash
# Create backup
docker-compose exec db pg_dump -U aml_user aml_monitoring > backup_$(date +%Y%m%d).sql

# Restore backup
docker-compose exec -T db psql -U aml_user aml_monitoring < backup_20240115.sql
```

### Automated Backups

Add to crontab:

```bash
0 2 * * * cd /path/to/app && docker-compose exec -T db pg_dump -U aml_user aml_monitoring > /backups/backup_$(date +\%Y\%m\%d).sql
```

## Troubleshooting

### Common Issues

1. **Port conflicts**
   ```bash
   # Check port usage
   lsof -i :80
   lsof -i :5432
   
   # Change ports in docker-compose.yml if needed
   ```

2. **Database connection errors**
   ```bash
   # Check database status
   docker-compose exec db psql -U aml_user -d aml_monitoring -c "SELECT 1"
   
   # Rebuild database
   docker-compose down -v
   docker-compose up -d db
   docker-compose exec backend alembic upgrade head
   ```

3. **Permission issues**
   ```bash
   # Fix file permissions
   sudo chown -R $USER:$USER .
   chmod -R 755 .
   ```

4. **Memory issues**
   ```bash
   # Check Docker resources
   docker system df
   docker system prune -a
   
   # Increase Docker memory limit
   # Edit Docker Desktop settings or daemon.json
   ```

### Debug Mode

Enable debug mode for development:

```bash
# Edit .env
DEBUG=True

# Restart services
docker-compose restart backend
```

## Performance Optimization

### Scaling

```bash
# Scale backend workers
docker-compose up -d --scale backend=3

# Configure nginx upstream in nginx/nginx.conf
upstream backend {
    least_conn;
    server backend_1:8000;
    server backend_2:8000;
    server backend_3:8000;
}
```

### Caching

Redis caching is configured for:
- Session data
- API responses
- Frequently accessed data

### Database Optimization

```sql
-- Add indexes for performance
CREATE INDEX idx_transactions_date ON ai_transactions(date);
CREATE INDEX idx_transactions_customer ON ai_transactions(customer_id);
CREATE INDEX idx_alerts_status ON alerts(status);
```

## Security Checklist

- [ ] Change default passwords
- [ ] Enable HTTPS/SSL
- [ ] Configure firewall rules
- [ ] Set up rate limiting
- [ ] Enable security headers
- [ ] Regular security updates
- [ ] Database backup encryption
- [ ] Log monitoring
- [ ] Access control review

## Maintenance

### Regular Updates

```bash
# Update base images
docker-compose pull
docker-compose build --no-cache
docker-compose up -d
```

### Database Maintenance

```bash
# Vacuum database
docker-compose exec db psql -U aml_user -d aml_monitoring -c "VACUUM ANALYZE;"

# Reindex tables
docker-compose exec db psql -U aml_user -d aml_monitoring -c "REINDEX DATABASE aml_monitoring;"
```

## Support

For issues or questions:
- GitHub Issues: https://github.com/denniszitha/fastapiaml/issues
- Email: admin@natsave.com