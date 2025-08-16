#!/usr/bin/env python3
"""
Container-based continuous population script for AML system
Runs inside Docker container and continuously generates realistic transaction data
"""

import os
import sys
import time
import random
import requests
import psycopg2
from datetime import datetime, timedelta
import signal
import json

# Configuration from environment
DB_HOST = os.getenv('DB_HOST', 'postgres')
DB_PORT = int(os.getenv('DB_PORT', 5432))
DB_NAME = os.getenv('DB_NAME', 'aml_monitoring')
DB_USER = os.getenv('DB_USER', 'aml_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'secure_password')

API_HOST = os.getenv('API_HOST', 'aml-backend')
API_PORT = int(os.getenv('API_PORT', 8000))
API_BASE = f"http://{API_HOST}:{API_PORT}/api/v1"

POPULATE_INTERVAL = int(os.getenv('POPULATE_INTERVAL', 5))
BATCH_SIZE = int(os.getenv('BATCH_SIZE', 5))

# Sample data
NAMES = [
    "John Smith", "Maria Garcia", "Li Wei", "Ahmed Hassan", "Sarah Johnson",
    "Emma Wilson", "James Brown", "Fatima Al-Said", "Michael Chen", "Anna Kowalski",
    "Global Trade Corp", "Tech Solutions Inc", "Import Export Ltd", 
    "International Finance LLC", "World Commerce Group", "Trade Bridge Co"
]

COUNTRIES = [
    "USA", "UK", "Canada", "UAE", "Singapore", "Nigeria", "Kenya", 
    "Germany", "France", "Japan", "Brazil", "India", "Australia", "Mexico"
]

HIGH_RISK_COUNTRIES = ["Iran", "Syria", "North Korea", "Afghanistan", "Yemen"]

TRANSACTION_TYPES = [
    "WIRE_TRANSFER", "ACH", "CASH_DEPOSIT", "CASH_WITHDRAWAL", 
    "INTERNATIONAL_WIRE", "MOBILE_PAYMENT"
]

# Statistics
stats = {
    "start_time": time.time(),
    "transactions": 0,
    "suspicious": 0,
    "profiles": 0,
    "errors": 0
}

def signal_handler(sig, frame):
    """Handle graceful shutdown"""
    print("\n\nShutting down data populator...")
    print_statistics()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def print_statistics():
    """Print current statistics"""
    runtime = time.time() - stats["start_time"]
    hours = int(runtime // 3600)
    minutes = int((runtime % 3600) // 60)
    
    print("\n" + "="*50)
    print("POPULATION STATISTICS")
    print("="*50)
    print(f"Runtime: {hours}h {minutes}m")
    print(f"Transactions Created: {stats['transactions']}")
    print(f"Suspicious Cases: {stats['suspicious']}")
    print(f"Customer Profiles: {stats['profiles']}")
    print(f"Errors: {stats['errors']}")
    if stats['transactions'] > 0:
        rate = (stats['transactions'] / (runtime / 60))
        print(f"Rate: {rate:.1f} transactions/minute")
    print("="*50)

def get_db_connection():
    """Get database connection with retry logic"""
    max_retries = 5
    for i in range(max_retries):
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD
            )
            return conn
        except Exception as e:
            if i < max_retries - 1:
                print(f"Database connection failed, retrying in 5 seconds...")
                time.sleep(5)
            else:
                print(f"Failed to connect to database: {e}")
                return None

def check_api_health():
    """Check if API is healthy"""
    try:
        response = requests.get(f"http://{API_HOST}:{API_PORT}/health", timeout=5)
        return response.status_code == 200
    except:
        return False

def create_customer_profile(conn):
    """Create a random customer profile in database"""
    cur = conn.cursor()
    
    account_number = f"{random.randint(1000,9999)}-{random.randint(100000,999999)}"
    name = random.choice(NAMES)
    is_company = any(corp in name for corp in ["Corp", "Inc", "Ltd", "LLC", "Group", "Co"])
    
    try:
        cur.execute("""
            INSERT INTO customer_profiles 
            (account_number, account_name, customer_type, risk_level, country, 
             is_pep, is_sanctioned, kyc_verified, account_balance, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (account_number) DO UPDATE
            SET account_balance = EXCLUDED.account_balance,
                updated_at = NOW()
            RETURNING account_number
        """, (
            account_number, 
            name,
            "CORPORATE" if is_company else "INDIVIDUAL",
            random.choices(["LOW", "MEDIUM", "HIGH", "CRITICAL"], weights=[40, 30, 20, 10])[0],
            random.choice(COUNTRIES),
            random.random() < 0.05,  # 5% PEP
            False,
            random.random() < 0.95,  # 95% KYC verified
            round(random.uniform(1000, 1000000), 2),
            datetime.now()
        ))
        conn.commit()
        stats["profiles"] += 1
        return account_number
    except Exception as e:
        conn.rollback()
        stats["errors"] += 1
        return None
    finally:
        cur.close()

def create_suspicious_case(conn, transaction_data):
    """Create a suspicious case in database"""
    cur = conn.cursor()
    
    case_number = f"SAR-{datetime.now().year}-{random.randint(10000, 99999)}"
    
    try:
        cur.execute("""
            INSERT INTO suspicious_cases 
            (case_number, account_number, account_name, transaction_amount, 
             risk_score, alert_reason, status, assigned_to, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (case_number) DO NOTHING
        """, (
            case_number,
            transaction_data["account_number"],
            transaction_data["account_name"],
            transaction_data["amount"],
            transaction_data["risk_score"],
            transaction_data["alert_reason"],
            "PENDING",
            random.choice(["Analyst1", "Analyst2", "Senior Analyst"]),
            datetime.now()
        ))
        conn.commit()
        if cur.rowcount > 0:
            stats["suspicious"] += 1
            return case_number
    except Exception as e:
        conn.rollback()
        stats["errors"] += 1
    finally:
        cur.close()
    return None

def generate_transaction():
    """Generate a random transaction"""
    sender_account = f"{random.randint(1000,9999)}-{random.randint(100000,999999)}"
    receiver_account = f"{random.randint(1000,9999)}-{random.randint(100000,999999)}"
    
    # Determine amount
    if random.random() < 0.05:  # 5% large
        amount = round(random.uniform(50000, 500000), 2)
    elif random.random() < 0.2:  # 20% medium
        amount = round(random.uniform(5000, 50000), 2)
    else:  # 75% small
        amount = round(random.uniform(100, 5000), 2)
    
    # Determine if suspicious
    risk_score = random.uniform(0, 40)
    alert_reasons = []
    
    if amount > 100000:
        risk_score += 30
        alert_reasons.append("Large transaction amount")
    
    sender_country = random.choice(COUNTRIES + HIGH_RISK_COUNTRIES)
    receiver_country = random.choice(COUNTRIES + HIGH_RISK_COUNTRIES)
    
    if sender_country in HIGH_RISK_COUNTRIES or receiver_country in HIGH_RISK_COUNTRIES:
        risk_score += 40
        alert_reasons.append("High-risk country involved")
    
    # Structuring check
    if amount in [9999, 9999.99, 9900, 9500]:
        risk_score += 25
        alert_reasons.append("Potential structuring")
    
    risk_score = min(risk_score, 100)
    
    return {
        "account_number": sender_account,
        "account_name": random.choice(NAMES),
        "receiver_account": receiver_account,
        "receiver_name": random.choice(NAMES),
        "amount": amount,
        "currency": "USD",
        "transaction_type": random.choice(TRANSACTION_TYPES),
        "sender_country": sender_country,
        "receiver_country": receiver_country,
        "risk_score": round(risk_score, 2),
        "alert_reason": ", ".join(alert_reasons) if alert_reasons else "Normal transaction",
        "is_suspicious": risk_score > 60
    }

def main():
    """Main loop"""
    print("="*50)
    print("AML CONTINUOUS DATA POPULATOR")
    print("="*50)
    print(f"Database: {DB_HOST}:{DB_PORT}/{DB_NAME}")
    print(f"API: {API_BASE}")
    print(f"Interval: {POPULATE_INTERVAL}s | Batch: {BATCH_SIZE}")
    print("="*50)
    print()
    
    # Wait for services to be ready
    print("Waiting for services to be ready...")
    while True:
        if check_api_health():
            print("✓ API is healthy")
            break
        print("  Waiting for API...")
        time.sleep(5)
    
    conn = get_db_connection()
    if not conn:
        print("✗ Failed to connect to database")
        sys.exit(1)
    print("✓ Connected to database")
    print()
    
    print("Starting continuous population...")
    print("Press Ctrl+C to stop")
    print()
    
    last_stats_time = time.time()
    
    while True:
        try:
            # Create batch of transactions
            for _ in range(BATCH_SIZE):
                # Occasionally create new profiles
                if random.random() < 0.1:
                    create_customer_profile(conn)
                
                # Generate transaction
                transaction = generate_transaction()
                stats["transactions"] += 1
                
                # Create suspicious case if needed
                if transaction["is_suspicious"]:
                    case_number = create_suspicious_case(conn, transaction)
                    if case_number:
                        print(f"⚠️  Suspicious case {case_number}: "
                              f"${transaction['amount']:,.2f} | Risk: {transaction['risk_score']}")
                
                # Show progress
                if stats["transactions"] % 10 == 0:
                    print(f"✓ Generated {stats['transactions']} transactions...")
            
            # Print statistics every minute
            if time.time() - last_stats_time > 60:
                print_statistics()
                last_stats_time = time.time()
            
            # Wait before next batch
            time.sleep(POPULATE_INTERVAL)
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error in main loop: {e}")
            stats["errors"] += 1
            time.sleep(5)
    
    # Cleanup
    if conn:
        conn.close()
    print_statistics()
    print("Populator stopped.")

if __name__ == "__main__":
    main()