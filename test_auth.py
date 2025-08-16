#!/usr/bin/env python3
"""
Test authentication endpoint
"""
import requests
import json
import sys

def test_auth(base_url="http://localhost:50000"):
    """Test authentication flow"""
    
    print(f"Testing authentication at {base_url}")
    print("=" * 50)
    
    # Test 1: Health check
    print("\n1. Testing health endpoint...")
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print(f"   Response: {response.json()}")
            print("   ✓ Health check passed")
        else:
            print("   ✗ Health check failed")
    except requests.exceptions.ConnectionError:
        print("   ✗ Connection refused - Backend is not running!")
        print("\n   To fix:")
        print("   1. Start backend: docker-compose up -d backend")
        print("   2. Or run: ./fix_auth_connection.sh")
        return False
    except Exception as e:
        print(f"   ✗ Error: {e}")
        return False
    
    # Test 2: Login
    print("\n2. Testing login endpoint...")
    try:
        # Prepare login data
        login_data = {
            "username": "admin@test.com",
            "password": "admin123"
        }
        
        # Try with form data (OAuth2 style)
        response = requests.post(
            f"{base_url}/api/v1/auth/login",
            data=login_data,
            timeout=5
        )
        
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            token_data = response.json()
            if "access_token" in token_data:
                print(f"   ✓ Login successful!")
                print(f"   Token: {token_data['access_token'][:50]}...")
                return token_data["access_token"]
            else:
                print("   ✗ No access token in response")
        elif response.status_code == 401:
            print("   ✗ Invalid credentials")
            print("   Expected: admin@test.com / admin123")
        elif response.status_code == 404:
            print("   ✗ Login endpoint not found")
            print("   Backend might not be configured correctly")
        elif response.status_code == 422:
            print("   ✗ Validation error")
            print(f"   Details: {response.json()}")
        else:
            print(f"   ✗ Unexpected status: {response.status_code}")
            print(f"   Response: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("   ✗ Connection refused on login endpoint")
    except Exception as e:
        print(f"   ✗ Error during login: {e}")
    
    # Test 3: Check CORS headers
    print("\n3. Testing CORS headers...")
    try:
        response = requests.options(
            f"{base_url}/api/v1/auth/login",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "POST"
            },
            timeout=5
        )
        
        cors_headers = {
            "Access-Control-Allow-Origin": response.headers.get("Access-Control-Allow-Origin"),
            "Access-Control-Allow-Methods": response.headers.get("Access-Control-Allow-Methods"),
            "Access-Control-Allow-Headers": response.headers.get("Access-Control-Allow-Headers"),
        }
        
        print("   CORS Headers:")
        for header, value in cors_headers.items():
            if value:
                print(f"   ✓ {header}: {value}")
            else:
                print(f"   ✗ {header}: Not set")
                
    except Exception as e:
        print(f"   ✗ Error checking CORS: {e}")
    
    print("\n" + "=" * 50)
    print("Test complete!")
    
    return True

if __name__ == "__main__":
    # Get base URL from command line or use default
    base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:50000"
    
    # Run tests
    success = test_auth(base_url)
    
    if not success:
        print("\n⚠️  Authentication tests failed!")
        print("\nTroubleshooting steps:")
        print("1. Check if backend is running: docker ps")
        print("2. Check logs: docker logs aml-backend")
        print("3. Try simple deployment: docker-compose -f docker-compose.simple.yml up -d")
        print("4. Run fix script: ./fix_auth_connection.sh")
        sys.exit(1)
    else:
        print("\n✅ All tests passed!")
        sys.exit(0)