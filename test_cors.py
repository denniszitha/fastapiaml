#!/usr/bin/env python3
"""
Script to test CORS configuration
"""
import requests
import sys
from urllib.parse import urljoin

def test_cors(base_url, origin="https://yourdomain.com"):
    """Test CORS configuration for various endpoints"""
    
    endpoints = [
        "/api/v1/health",
        "/api/v1/auth/login",
        "/api/v1/statistics/dashboard",
        "/api/v1/watchlist",
    ]
    
    print(f"Testing CORS for {base_url} with origin {origin}")
    print("=" * 60)
    
    results = []
    
    for endpoint in endpoints:
        url = urljoin(base_url, endpoint)
        
        # Test preflight request
        print(f"\nTesting OPTIONS {endpoint}")
        try:
            response = requests.options(
                url,
                headers={
                    "Origin": origin,
                    "Access-Control-Request-Method": "POST",
                    "Access-Control-Request-Headers": "Content-Type,Authorization"
                },
                timeout=5
            )
            
            cors_headers = {
                "Access-Control-Allow-Origin": response.headers.get("Access-Control-Allow-Origin"),
                "Access-Control-Allow-Methods": response.headers.get("Access-Control-Allow-Methods"),
                "Access-Control-Allow-Headers": response.headers.get("Access-Control-Allow-Headers"),
                "Access-Control-Allow-Credentials": response.headers.get("Access-Control-Allow-Credentials"),
            }
            
            print(f"  Status: {response.status_code}")
            print(f"  CORS Headers:")
            for header, value in cors_headers.items():
                status = "✓" if value else "✗"
                print(f"    {status} {header}: {value or 'Not set'}")
            
            # Check if CORS is properly configured
            cors_ok = (
                response.status_code in [200, 204] and
                cors_headers["Access-Control-Allow-Origin"] in [origin, "*"] and
                cors_headers["Access-Control-Allow-Methods"] is not None
            )
            
            results.append({
                "endpoint": endpoint,
                "method": "OPTIONS",
                "status": response.status_code,
                "cors_ok": cors_ok
            })
            
        except requests.exceptions.RequestException as e:
            print(f"  Error: {e}")
            results.append({
                "endpoint": endpoint,
                "method": "OPTIONS",
                "status": "error",
                "cors_ok": False
            })
        
        # Test GET request with Origin header
        print(f"\nTesting GET {endpoint}")
        try:
            response = requests.get(
                url,
                headers={"Origin": origin},
                timeout=5
            )
            
            cors_origin = response.headers.get("Access-Control-Allow-Origin")
            cors_credentials = response.headers.get("Access-Control-Allow-Credentials")
            
            print(f"  Status: {response.status_code}")
            print(f"  Access-Control-Allow-Origin: {cors_origin or 'Not set'}")
            print(f"  Access-Control-Allow-Credentials: {cors_credentials or 'Not set'}")
            
            cors_ok = cors_origin in [origin, "*"]
            
            results.append({
                "endpoint": endpoint,
                "method": "GET",
                "status": response.status_code,
                "cors_ok": cors_ok
            })
            
        except requests.exceptions.RequestException as e:
            print(f"  Error: {e}")
            results.append({
                "endpoint": endpoint,
                "method": "GET",
                "status": "error",
                "cors_ok": False
            })
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    total_tests = len(results)
    passed_tests = sum(1 for r in results if r["cors_ok"])
    
    for result in results:
        status = "✓ PASS" if result["cors_ok"] else "✗ FAIL"
        print(f"{status} - {result['method']:7} {result['endpoint']:30} (Status: {result['status']})")
    
    print(f"\nTotal: {passed_tests}/{total_tests} tests passed")
    
    return passed_tests == total_tests

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_cors.py <base_url> [origin]")
        print("Example: python test_cors.py http://localhost:50000 https://yourdomain.com")
        sys.exit(1)
    
    base_url = sys.argv[1]
    origin = sys.argv[2] if len(sys.argv) > 2 else "https://yourdomain.com"
    
    success = test_cors(base_url, origin)
    sys.exit(0 if success else 1)