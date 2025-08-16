#!/bin/bash

# ============================================
# FIX API ENDPOINT CONFIGURATION
# ============================================
# This script fixes the frontend API configuration
# to properly connect through the nginx proxy
# ============================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PUBLIC_IP=${PUBLIC_IP:-$(curl -s http://checkip.amazonaws.com || echo "localhost")}
FRONTEND_PORT=${FRONTEND_PORT:-8888}
BACKEND_PORT=${BACKEND_PORT:-8000}

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}FIXING API ENDPOINT CONFIGURATION${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Current Configuration:${NC}"
echo "  Public IP: $PUBLIC_IP"
echo "  Frontend Port: $FRONTEND_PORT"
echo "  Backend Port: $BACKEND_PORT"
echo ""

# Step 1: Check current services
echo -e "${GREEN}Step 1: Checking services...${NC}"
echo "-----------------------------"

# Check backend
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$BACKEND_PORT/health 2>/dev/null || echo "000")
if [ "$BACKEND_STATUS" = "200" ]; then
    echo "✓ Backend is running on port $BACKEND_PORT"
else
    echo -e "${RED}✗ Backend is not accessible on port $BACKEND_PORT${NC}"
fi

# Check frontend
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT 2>/dev/null || echo "000")
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✓ Frontend is running on port $FRONTEND_PORT"
else
    echo -e "${RED}✗ Frontend is not accessible on port $FRONTEND_PORT${NC}"
fi

# Step 2: Fix API configuration in source
echo ""
echo -e "${GREEN}Step 2: Updating API configuration...${NC}"
echo "-------------------------------------"

# Update the API configuration file
cat > aml-frontend/src/services/api.js << 'EOF'
import axios from 'axios';
import toast from 'react-hot-toast';

// Use relative URL for production - nginx will proxy to backend
const API_BASE_URL = process.env.REACT_APP_API_URL || '/api/v1';

console.log('API Base URL:', API_BASE_URL);

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  // Don't use withCredentials for token-based auth
  withCredentials: false,
});

// Request interceptor for auth
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    console.log('API Request:', config.method.toUpperCase(), config.url);
    return config;
  },
  (error) => {
    console.error('Request Error:', error);
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => {
    console.log('API Response:', response.status, response.config.url);
    return response;
  },
  (error) => {
    console.error('API Error:', error.response?.status, error.config?.url, error.message);
    
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    } else if (error.response?.status === 500) {
      toast.error('Server error. Please try again later.');
    } else if (!error.response) {
      // Network error - nginx proxy might be misconfigured
      console.error('Network Error - Check nginx proxy configuration');
      toast.error('Cannot connect to server. Please check your connection.');
    }
    return Promise.reject(error);
  }
);

// Transaction Monitoring APIs
export const transactionAPI = {
  processTransaction: (data) => api.post('/webhook/suspicious', data),
  getMonitoringStatus: () => api.get('/monitoring/status'),
  toggleMonitoring: (enable) => api.post(`/monitoring/toggle?enable=${enable}`),
};

// Watchlist APIs
export const watchlistAPI = {
  getAll: () => api.get('/watchlist'),
  add: (data) => api.post('/watchlist', data),
  remove: (accountNumber) => api.delete(`/watchlist/${accountNumber}`),
};

// Exemptions APIs
export const exemptionsAPI = {
  getAll: (params) => api.get('/exemptions', { params }),
  add: (data) => api.post('/exemptions', data),
  remove: (accountNumber) => api.delete(`/exemptions/${accountNumber}`),
};

// Transaction Limits APIs
export const limitsAPI = {
  getAll: () => api.get('/limits'),
  add: (data) => api.post('/limits', data),
  update: (id, data) => api.put(`/limits/${id}`, data),
  remove: (id) => api.delete(`/limits/${id}`),
};

// Customer Profiles APIs
export const profilesAPI = {
  getAll: () => api.get('/profiles'),
  getById: (accountNumber) => api.get(`/profiles/${accountNumber}`),
  update: (accountNumber, data) => api.put(`/profiles/${accountNumber}`, data),
};

// Suspicious Cases APIs
export const casesAPI = {
  getAll: (params) => api.get('/suspicious-cases', { params }),
  getById: (caseNumber) => api.get(`/suspicious-cases/${caseNumber}`),
  update: (caseNumber, data) => api.put(`/suspicious-cases/${caseNumber}`, data),
};

// Statistics APIs
export const statisticsAPI = {
  getDashboard: () => api.get('/statistics/dashboard'),
  getTransactionVolume: (params) => api.get('/statistics/transactions/volume', { params }),
  getRiskDistribution: () => api.get('/statistics/risk/distribution'),
  getPerformanceKPIs: () => api.get('/statistics/performance/kpis'),
};

// Reports APIs
export const reportsAPI = {
  generate: (data) => api.post('/reports/generate', data),
  getSTR: (caseNumber) => api.get(`/reports/str/${caseNumber}`),
  getCompliance: (params) => api.get('/reports/compliance/monthly', { params }),
};

// Auth APIs
export const authAPI = {
  login: (credentials) => api.post('/auth/login', credentials),
  register: (userData) => api.post('/auth/register', userData),
  logout: () => api.post('/auth/logout'),
  getMe: () => api.get('/auth/me'),
  changePassword: (data) => api.post('/auth/change-password', data),
};

export default api;
EOF

echo "✓ API configuration updated"

# Step 3: Update nginx configuration
echo ""
echo -e "${GREEN}Step 3: Updating nginx configuration...${NC}"
echo "----------------------------------------"

cat > nginx/api-proxy.conf << EOF
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Logging for debugging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log debug;
    
    # Frontend application
    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    
    # API proxy - IMPORTANT: This must match the API_BASE_URL in React
    location /api/v1/ {
        # Log proxy attempts
        access_log /var/log/nginx/api-access.log;
        
        # Try multiple backend endpoints
        proxy_pass http://172.17.0.1:$BACKEND_PORT/api/v1/;
        
        # Proper headers for proxy
        proxy_http_version 1.1;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Handle OPTIONS requests for CORS
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
        
        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Error handling
        proxy_intercept_errors off;
    }
    
    # Alternative API endpoints for testing
    location /api-test/ {
        proxy_pass http://host.docker.internal:$BACKEND_PORT/api/v1/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
    
    # Direct health check
    location /api/v1/health {
        proxy_pass http://172.17.0.1:$BACKEND_PORT/api/v1/health;
        proxy_http_version 1.1;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1h;
        add_header Cache-Control "public";
    }
}
EOF

echo "✓ Nginx configuration updated"

# Step 4: Rebuild frontend
echo ""
echo -e "${GREEN}Step 4: Rebuilding frontend...${NC}"
echo "------------------------------"
read -p "Do you want to rebuild the React app? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd aml-frontend
    
    # Clean and rebuild
    echo "Cleaning old build..."
    rm -rf build
    
    # Set environment to use proxy
    unset REACT_APP_API_URL
    export NODE_OPTIONS="--max-old-space-size=2048"
    
    echo "Building with API proxy configuration..."
    npm run build || {
        echo -e "${YELLOW}Build failed, trying with legacy deps...${NC}"
        npm install --legacy-peer-deps
        npm run build
    }
    
    if [ -f "build/index.html" ]; then
        echo "✓ Frontend rebuilt successfully"
    else
        echo -e "${RED}✗ Build failed${NC}"
    fi
    
    cd ..
else
    echo "Skipping rebuild - will update container with new nginx config only"
fi

# Step 5: Update frontend container
echo ""
echo -e "${GREEN}Step 5: Updating frontend container...${NC}"
echo "--------------------------------------"

# Stop old container
sudo docker stop aml-frontend 2>/dev/null || true
sudo docker rm aml-frontend 2>/dev/null || true

# Start with new configuration
sudo docker run -d \
  --name aml-frontend \
  -v $(pwd)/aml-frontend/build:/usr/share/nginx/html:ro \
  -v $(pwd)/nginx/api-proxy.conf:/etc/nginx/conf.d/default.conf:ro \
  -p $FRONTEND_PORT:80 \
  --add-host=host.docker.internal:host-gateway \
  --restart always \
  nginx:alpine

echo "Waiting for container to start..."
sleep 3

# Step 6: Test the configuration
echo ""
echo -e "${GREEN}Step 6: Testing API connectivity...${NC}"
echo "-----------------------------------"

# Test frontend
echo "Testing frontend..."
FRONTEND_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT)
echo "  Frontend: HTTP $FRONTEND_TEST"

# Test API through proxy
echo "Testing API proxy..."
API_PROXY_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT/api/v1/health)
echo "  API via proxy: HTTP $API_PROXY_TEST"

# Test with curl what the browser would see
echo ""
echo "Testing login endpoint via proxy..."
LOGIN_TEST=$(curl -s -X POST http://localhost:$FRONTEND_PORT/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  -w "\nHTTP Status: %{http_code}\n" 2>&1)
echo "$LOGIN_TEST" | head -5

# Check nginx logs
echo ""
echo "Recent nginx access logs:"
sudo docker exec aml-frontend tail -5 /var/log/nginx/access.log 2>/dev/null || echo "No logs yet"

echo ""
echo "Recent nginx error logs:"
sudo docker exec aml-frontend tail -5 /var/log/nginx/error.log 2>/dev/null || echo "No errors"

# Final message
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}API ENDPOINT FIX COMPLETE${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${BLUE}The frontend should now connect properly to the backend.${NC}"
echo ""
echo "Access points:"
echo "  Frontend: http://$PUBLIC_IP:$FRONTEND_PORT"
echo "  Login: Use username 'admin' and password 'admin123'"
echo ""
echo "If still having issues:"
echo "  1. Clear browser cache (Ctrl+Shift+R)"
echo "  2. Check browser console for errors"
echo "  3. View nginx logs: sudo docker logs aml-frontend"
echo "  4. Test API directly: curl http://$PUBLIC_IP:$FRONTEND_PORT/api/v1/health"
echo ""