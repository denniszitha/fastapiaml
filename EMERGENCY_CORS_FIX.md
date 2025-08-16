# Emergency CORS Fix

If you're still experiencing CORS issues after deployment, follow these steps:

## Quick Fix (Allow All Origins)

### 1. Update Backend main.py
The main.py has been updated to allow all origins with:
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)
```

### 2. Deploy the Fix
```bash
# Option A: Using docker-compose
./deploy_fix_cors.sh

# Option B: Manual deployment
docker-compose down
docker-compose build backend
docker-compose up -d
```

### 3. If Using Nginx Proxy
Add these headers to your nginx configuration:
```nginx
location /api/ {
    # Handle OPTIONS
    if ($request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD' always;
        add_header 'Access-Control-Allow-Headers' '*' always;
        add_header 'Access-Control-Max-Age' 86400;
        add_header 'Content-Type' 'text/plain; charset=utf-8';
        add_header 'Content-Length' 0;
        return 204;
    }
    
    # Proxy and add headers
    proxy_pass http://backend:50000;
    
    # Always add CORS headers
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD' always;
    add_header 'Access-Control-Allow-Headers' '*' always;
}
```

### 4. Frontend Configuration
Make sure your frontend is NOT sending credentials if allowing all origins:
```javascript
// In api.js - remove withCredentials when using wildcard origins
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  // withCredentials: false, // Set to false when using allow_origins=["*"]
});
```

## Testing CORS

### 1. Test with curl
```bash
# Test OPTIONS (preflight)
curl -I -X OPTIONS http://your-domain/api/v1/health \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET"

# Should see:
# Access-Control-Allow-Origin: *
# Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD
```

### 2. Test with browser
Open `test_cors_simple.html` in your browser and update the API_URL.

### 3. Browser Console Test
```javascript
fetch('http://your-domain/api/v1/health')
  .then(r => r.json())
  .then(console.log)
  .catch(console.error)
```

## Common Issues

### Issue: "CORS header 'Access-Control-Allow-Origin' missing"
**Solution**: Backend is not adding CORS headers. Check if middleware is loaded.

### Issue: "CORS policy: Cannot use wildcard in Access-Control-Allow-Origin when credentials flag is true"
**Solution**: Either:
1. Remove `withCredentials: true` from frontend
2. OR specify exact origins instead of "*"

### Issue: Works locally but not in production
**Solution**: Check nginx/proxy configuration. The proxy might be stripping headers.

## Nuclear Option (Not Recommended for Production)

If nothing else works, create this endpoint in your backend:
```python
from fastapi import Request

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH", "HEAD"])
async def catch_all(request: Request, path: str):
    # Handle OPTIONS
    if request.method == "OPTIONS":
        return Response(
            content="",
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*",
            }
        )
    
    # Forward to actual endpoint with CORS headers
    # ... your routing logic here
```

## Verification Steps

After applying the fix:
1. Restart all services
2. Clear browser cache
3. Test in incognito mode
4. Check network tab for CORS headers
5. Verify no proxy is blocking headers

## Still Not Working?

1. Check Docker logs: `docker-compose logs backend`
2. Verify backend is running: `curl http://localhost:50000/health`
3. Check if behind CloudFlare or other CDN (they might strip headers)
4. Ensure no browser extensions are blocking requests
5. Try a different browser

Remember: CORS is a browser security feature. Tools like Postman/curl will always work because they don't enforce CORS.