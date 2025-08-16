# CORS and Authentication Troubleshooting Guide

## Common Issues and Solutions

### 1. CORS Policy Violations

#### Symptoms:
- Browser console shows: "Access to XMLHttpRequest at '...' from origin '...' has been blocked by CORS policy"
- Authentication fails with CORS errors
- API calls fail from frontend but work in Postman/curl

#### Solutions:

1. **Check Environment Variables**
   ```bash
   # In .env.production
   CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
   ```

2. **Verify Nginx Configuration**
   - Ensure nginx is properly forwarding headers
   - Check that preflight requests (OPTIONS) are handled

3. **Test CORS Configuration**
   ```bash
   # Run the CORS test script
   python test_cors.py http://localhost:50000 https://yourdomain.com
   ```

### 2. Authentication Failures

#### Symptoms:
- Login returns 401 even with correct credentials
- Token not being sent with requests
- Session expires immediately

#### Solutions:

1. **Check Token Storage**
   ```javascript
   // In browser console
   localStorage.getItem('token')
   ```

2. **Verify Backend is Running**
   ```bash
   curl http://localhost:50000/api/v1/health
   ```

3. **Check Database Connection**
   ```bash
   # Test database connection
   docker-compose exec postgres psql -U aml_user -d aml_database -c "SELECT 1;"
   ```

### 3. Network Connectivity Issues

#### Symptoms:
- "Network Error" in browser console
- Timeouts on API calls
- ERR_CONNECTION_REFUSED

#### Solutions:

1. **Check Service Status**
   ```bash
   # Check if all services are running
   docker-compose ps
   
   # Check logs
   docker-compose logs backend
   docker-compose logs nginx
   ```

2. **Verify Port Availability**
   ```bash
   # Check if ports are open
   netstat -tulpn | grep -E "80|443|50000"
   ```

3. **Test Backend Directly**
   ```bash
   # Bypass nginx and test backend directly
   curl http://localhost:50000/api/v1/health
   ```

### 4. Internal Server Errors (500)

#### Symptoms:
- API returns 500 status code
- "Internal Server Error" message
- Operations fail silently

#### Solutions:

1. **Check Backend Logs**
   ```bash
   docker-compose logs -f backend --tail=100
   ```

2. **Verify Database Migrations**
   ```bash
   # Run migrations manually
   docker-compose exec backend python -m alembic upgrade head
   ```

3. **Check File Permissions**
   ```bash
   # Ensure proper permissions
   ls -la /app
   chown -R 1000:1000 /app
   ```

## Testing Checklist

### Local Development
- [ ] Backend starts without errors
- [ ] Frontend connects to backend
- [ ] Login works with test credentials
- [ ] API calls succeed from frontend
- [ ] No CORS errors in browser console

### Production Deployment
- [ ] SSL certificates are valid
- [ ] Domain names are correctly configured
- [ ] Environment variables are set
- [ ] Database is accessible
- [ ] Nginx is routing correctly
- [ ] CORS headers are present in responses
- [ ] Health checks pass

## Quick Fixes

### Reset Everything
```bash
# Stop all services
docker-compose down -v

# Rebuild and start
docker-compose up --build -d

# Check logs
docker-compose logs -f
```

### Create Test User
```bash
# Run the test user creation script
python create_test_user.py
```

### Test Authentication
```bash
# Test login
curl -X POST http://localhost:50000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@test.com&password=admin123"
```

### Enable Debug Mode
```bash
# In .env file
DEBUG=True
LOG_LEVEL=DEBUG
```

## Contact Support

If issues persist after trying these solutions:
1. Collect logs: `docker-compose logs > debug.log`
2. Run CORS test: `python test_cors.py http://your-domain.com > cors_test.log`
3. Check browser console and network tab
4. Document the exact error messages and steps to reproduce