#!/usr/bin/env python3
"""
Simple Database Population Script for AML System Docker Containers
Continuously generates test data directly into the containerized monitoring system
"""

import requests
import random
import time
import json
from datetime import datetime, timedelta
import sys
import os

# Configuration - Works with Docker containers
# Try different connection methods in order
API_BASE = None
ENDPOINTS_TO_TRY = [
    ("Docker container (localhost:8000)", "http://localhost:8000/api/v1"),
    ("Docker container (localhost:50000)", "http://localhost:50000/api/v1"),
    ("Public IP", f"http://{os.getenv('PUBLIC_IP', '102.23.120.243')}:8000/api/v1"),
    ("Docker host", "http://host.docker.internal:8000/api/v1"),
    ("Docker network", "http://aml-backend:8000/api/v1"),
]

print("Detecting backend connection...")
for name, endpoint in ENDPOINTS_TO_TRY:
    try:
        r = requests.get(f"{endpoint.replace('/api/v1', '')}/health", timeout=2)
        if r.status_code == 200:
            API_BASE = endpoint
            print(f"✓ Connected via: {name}")
            break
    except:
        continue

if not API_BASE:
    print("⚠️  Could not connect to backend. Using default.")
    API_BASE = "http://localhost:8000/api/v1"

# Sample data
NAMES = ["John Smith", "Maria Garcia", "Li Wei", "Ahmed Hassan", "Sarah Johnson",
         "Global Trade Corp", "Tech Solutions Inc", "Import Export Ltd"]

COUNTRIES = ["USA", "UK", "Canada", "UAE", "Singapore", "Nigeria", "Kenya"]
HIGH_RISK_COUNTRIES = ["Iran", "Syria", "North Korea"]

print("="*50)
print("AML Database Population Script")
print(f"API: {API_BASE}")
print("Press Ctrl+C to stop")
print("="*50)

# Login first to get token (if needed)
token = None
try:
    login_response = requests.post(
        f"{API_BASE}/auth/login",
        data={"username": "admin", "password": "admin123"}
    )
    if login_response.status_code == 200:
        token = login_response.json().get("access_token")
        print("✓ Logged in successfully")
except:
    print("⚠️  Authentication not required or failed")

headers = {"Authorization": f"Bearer {token}"} if token else {}

# Statistics
stats = {
    "watchlist": 0,
    "exemptions": 0, 
    "limits": 0,
    "suspicious": 0,
    "errors": 0
}

def add_to_watchlist():
    """Add entry to watchlist"""
    data = {
        "account_number": f"{random.randint(1000,9999)}-{random.randint(100000,999999)}",
        "account_name": random.choice(NAMES),
        "reason": random.choice([
            "Suspicious activity detected",
            "PEP - Politically Exposed Person",
            "High-risk jurisdiction",
            "Under investigation",
            "Sanctions list match"
        ]),
        "risk_level": random.choice(["HIGH", "CRITICAL"]),
        "added_by": "System",
        "is_active": True
    }
    
    try:
        r = requests.post(f"{API_BASE}/watchlist", json=data, headers=headers)
        if r.status_code in [200, 201]:
            stats["watchlist"] += 1
            print(f"✓ Added to watchlist: {data['account_name']}")
            return True
    except Exception as e:
        stats["errors"] += 1
    return False

def add_exemption():
    """Add transaction exemption"""
    data = {
        "account_number": f"{random.randint(1000,9999)}-{random.randint(100000,999999)}",
        "account_name": random.choice(NAMES),
        "exemption_type": random.choice(["temporary", "permanent", "conditional"]),
        "reason": random.choice([
            "Government account",
            "Verified charity organization",
            "Embassy account",
            "Internal transfer account",
            "Approved by compliance"
        ]),
        "start_date": datetime.now().isoformat(),
        "end_date": (datetime.now() + timedelta(days=random.randint(30, 365))).isoformat() if random.random() > 0.3 else None,
        "approved_by": "Compliance Officer",
        "is_active": True
    }
    
    try:
        r = requests.post(f"{API_BASE}/exemptions", json=data, headers=headers)
        if r.status_code in [200, 201]:
            stats["exemptions"] += 1
            print(f"✓ Added exemption: {data['account_name']}")
            return True
    except Exception as e:
        stats["errors"] += 1
    return False

def add_transaction_limit():
    """Add transaction limit"""
    data = {
        "limit_type": random.choice(["daily", "monthly", "per_transaction"]),
        "currency": "USD",
        "min_amount": random.choice([1000, 5000, 10000]),
        "max_amount": random.choice([50000, 100000, 500000, 1000000]),
        "customer_type": random.choice(["INDIVIDUAL", "CORPORATE", "ALL"]),
        "is_active": True
    }
    
    try:
        r = requests.post(f"{API_BASE}/limits", json=data, headers=headers)
        if r.status_code in [200, 201]:
            stats["limits"] += 1
            print(f"✓ Added limit: {data['limit_type']} - ${data['max_amount']:,}")
            return True
    except Exception as e:
        stats["errors"] += 1
    return False

def create_suspicious_transaction():
    """Simulate suspicious transaction webhook"""
    transaction_data = {
        "current_transaction": {
            "acct_no": f"{random.randint(1000,9999)}-{random.randint(100000,999999)}",
            "account_name": random.choice(NAMES),
            "amount": round(random.uniform(10000, 500000), 2),
            "currency": "USD",
            "transaction_type": random.choice(["WIRE", "CASH", "CHECK"]),
            "sender_country": random.choice(COUNTRIES + HIGH_RISK_COUNTRIES),
            "receiver_country": random.choice(COUNTRIES),
            "description": "International transfer",
            "risk_score": round(random.uniform(60, 100), 2)
        },
        "perm": "webhook_token_123"  # This would be a real token in production
    }
    
    try:
        r = requests.post(
            f"{API_BASE}/webhook/suspicious",
            json=transaction_data,
            headers=headers
        )
        if r.status_code in [200, 201]:
            stats["suspicious"] += 1
            amount = transaction_data["current_transaction"]["amount"]
            print(f"⚠️  Suspicious transaction: ${amount:,.2f} - Risk: {transaction_data['current_transaction']['risk_score']}")
            return True
    except Exception as e:
        stats["errors"] += 1
    return False

def print_stats():
    """Print current statistics"""
    print("\n" + "="*50)
    print("Current Statistics:")
    print(f"  Watchlist entries: {stats['watchlist']}")
    print(f"  Exemptions: {stats['exemptions']}")
    print(f"  Transaction limits: {stats['limits']}")
    print(f"  Suspicious transactions: {stats['suspicious']}")
    print(f"  Errors: {stats['errors']}")
    print("="*50 + "\n")

def main():
    """Main loop"""
    iteration = 0
    
    print("\nStarting continuous data generation...\n")
    
    try:
        while True:
            iteration += 1
            
            # Random action each iteration
            action = random.choice([
                add_to_watchlist,
                add_exemption,
                add_transaction_limit,
                create_suspicious_transaction,
                create_suspicious_transaction  # Higher chance for transactions
            ])
            
            action()
            
            # Print stats every 20 iterations
            if iteration % 20 == 0:
                print_stats()
            
            # Random delay between actions (0.5 to 3 seconds)
            time.sleep(random.uniform(0.5, 3))
            
    except KeyboardInterrupt:
        print("\n\nStopping...")
        print_stats()
        print("Goodbye!")

if __name__ == "__main__":
    # Check API health first
    try:
        r = requests.get(f"{API_BASE.replace('/api/v1', '')}/health")
        if r.status_code == 200:
            print("✓ API is healthy\n")
        else:
            print(f"⚠️  API returned status {r.status_code}")
    except Exception as e:
        print(f"⚠️  Cannot reach API: {e}")
        print("Make sure the backend is running!")
        sys.exit(1)
    
    main()