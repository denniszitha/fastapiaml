#!/usr/bin/env python3
"""
Continuous Database Population Script for AML System Testing
This script simulates real-time transaction flow for testing purposes
"""

import asyncio
import random
import time
from datetime import datetime, timedelta
import requests
import json
from typing import List, Dict, Any
import signal
import sys

# Configuration
API_BASE_URL = "http://localhost:8000/api/v1"
PUBLIC_IP = "102.23.120.243"

# Use public IP if available
try:
    response = requests.get(f"http://{PUBLIC_IP}:8000/health", timeout=2)
    if response.status_code == 200:
        API_BASE_URL = f"http://{PUBLIC_IP}:8000/api/v1"
except:
    pass

# Sample data for realistic transactions
FIRST_NAMES = ["John", "Mary", "James", "Patricia", "Robert", "Jennifer", "Michael", "Linda", 
                "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
                "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa"]

LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
               "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
               "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson"]

COMPANY_NAMES = ["Global Trade Co", "Import Export Ltd", "International Services", "Tech Solutions",
                 "Financial Partners", "Investment Group", "Trading House", "Business Ventures",
                 "Commerce International", "World Trade Inc", "Global Finance", "Trade Connect"]

COUNTRIES = ["USA", "UK", "Canada", "Germany", "France", "Japan", "China", "Brazil", "India",
             "Australia", "Singapore", "UAE", "Switzerland", "Netherlands", "Sweden", "Nigeria",
             "Kenya", "South Africa", "Mexico", "Italy", "Spain", "Russia", "Saudi Arabia"]

TRANSACTION_TYPES = ["WIRE_TRANSFER", "ACH", "CASH_DEPOSIT", "CASH_WITHDRAWAL", "CHECK_DEPOSIT",
                     "INTERNAL_TRANSFER", "INTERNATIONAL_WIRE", "MOBILE_PAYMENT", "ATM_WITHDRAWAL"]

CURRENCIES = ["USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "CNY", "INR", "BRL", "MXN"]

# High-risk countries for occasional suspicious transactions
HIGH_RISK_COUNTRIES = ["Iran", "North Korea", "Syria", "Afghanistan", "Yemen", "Somalia", "Libya"]

# Statistics tracking
stats = {
    "total_transactions": 0,
    "suspicious_transactions": 0,
    "customers_created": 0,
    "errors": 0,
    "start_time": time.time()
}

def signal_handler(sig, frame):
    """Handle graceful shutdown"""
    print("\n\nShutting down...")
    print_statistics()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def print_statistics():
    """Print current statistics"""
    runtime = time.time() - stats["start_time"]
    hours = runtime // 3600
    minutes = (runtime % 3600) // 60
    seconds = runtime % 60
    
    print("\n" + "="*50)
    print("DATABASE POPULATION STATISTICS")
    print("="*50)
    print(f"Runtime: {int(hours)}h {int(minutes)}m {int(seconds)}s")
    print(f"Total Transactions Created: {stats['total_transactions']}")
    print(f"Suspicious Transactions: {stats['suspicious_transactions']}")
    print(f"Customers Created: {stats['customers_created']}")
    print(f"Errors Encountered: {stats['errors']}")
    if stats['total_transactions'] > 0:
        print(f"Suspicious Rate: {(stats['suspicious_transactions']/stats['total_transactions']*100):.2f}%")
    print(f"Transactions per minute: {(stats['total_transactions']/(runtime/60)):.2f}")
    print("="*50)

def generate_account_number():
    """Generate a realistic account number"""
    return f"{random.randint(1000, 9999)}-{random.randint(100000, 999999)}-{random.randint(10, 99)}"

def generate_customer():
    """Generate a random customer profile"""
    is_company = random.random() < 0.3
    
    if is_company:
        name = random.choice(COMPANY_NAMES)
        customer_type = "CORPORATE"
    else:
        name = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
        customer_type = "INDIVIDUAL"
    
    # 10% chance of being high risk
    risk_level = random.choices(
        ["LOW", "MEDIUM", "HIGH", "CRITICAL"],
        weights=[50, 30, 15, 5]
    )[0]
    
    return {
        "account_number": generate_account_number(),
        "account_name": name,
        "customer_type": customer_type,
        "risk_level": risk_level,
        "country": random.choice(COUNTRIES),
        "is_pep": random.random() < 0.05,  # 5% chance of being PEP
        "is_sanctioned": False,
        "kyc_verified": random.random() < 0.95,  # 95% KYC verified
        "account_balance": round(random.uniform(1000, 1000000), 2),
        "currency": random.choice(CURRENCIES[:3]),  # Mostly major currencies
        "created_date": (datetime.now() - timedelta(days=random.randint(1, 365))).isoformat()
    }

def generate_transaction(customers: List[Dict], transaction_id: int):
    """Generate a random transaction"""
    sender = random.choice(customers)
    receiver = random.choice(customers)
    
    # Avoid self-transactions
    while sender == receiver:
        receiver = random.choice(customers)
    
    # Base amount - occasional large transactions
    if random.random() < 0.05:  # 5% large transactions
        amount = round(random.uniform(50000, 500000), 2)
    elif random.random() < 0.2:  # 20% medium transactions
        amount = round(random.uniform(5000, 50000), 2)
    else:  # 75% small transactions
        amount = round(random.uniform(10, 5000), 2)
    
    # Determine if suspicious
    is_suspicious = False
    suspicious_reasons = []
    risk_score = random.uniform(0, 30)  # Base risk score
    
    # Check for suspicious patterns
    if amount > 100000:
        is_suspicious = True
        suspicious_reasons.append("Large transaction amount")
        risk_score += 30
    
    if sender.get("risk_level") in ["HIGH", "CRITICAL"] or receiver.get("risk_level") in ["HIGH", "CRITICAL"]:
        risk_score += 20
        if random.random() < 0.3:
            is_suspicious = True
            suspicious_reasons.append("High-risk customer involved")
    
    # Occasional suspicious country
    if random.random() < 0.02:  # 2% chance
        receiver["country"] = random.choice(HIGH_RISK_COUNTRIES)
        is_suspicious = True
        suspicious_reasons.append("Transaction to high-risk country")
        risk_score += 40
    
    # Structuring pattern (multiple similar amounts)
    if amount in [9999, 9999.99, 9900, 9500] and random.random() < 0.5:
        is_suspicious = True
        suspicious_reasons.append("Potential structuring pattern")
        risk_score += 25
    
    # Round number transactions
    if amount % 1000 == 0 and amount > 10000:
        risk_score += 10
    
    risk_score = min(risk_score, 100)  # Cap at 100
    
    transaction = {
        "transaction_id": f"TXN-{transaction_id:08d}",
        "sender_account": sender.get("account_number"),
        "sender_name": sender.get("account_name"),
        "sender_country": sender.get("country"),
        "receiver_account": receiver.get("account_number"),
        "receiver_name": receiver.get("account_name"),
        "receiver_country": receiver.get("country"),
        "amount": amount,
        "currency": random.choice(CURRENCIES),
        "transaction_type": random.choice(TRANSACTION_TYPES),
        "transaction_date": datetime.now().isoformat(),
        "description": generate_transaction_description(sender, receiver, amount),
        "risk_score": round(risk_score, 2),
        "is_suspicious": is_suspicious,
        "suspicious_reasons": ", ".join(suspicious_reasons) if suspicious_reasons else None,
        "status": "COMPLETED" if not is_suspicious else random.choice(["PENDING_REVIEW", "UNDER_INVESTIGATION", "COMPLETED"]),
        "swift_code": f"SWIFT{random.randint(10000, 99999)}",
        "reference_number": f"REF-{random.randint(100000, 999999)}"
    }
    
    if is_suspicious:
        stats["suspicious_transactions"] += 1
    
    return transaction

def generate_transaction_description(sender: Dict, receiver: Dict, amount: float):
    """Generate realistic transaction descriptions"""
    descriptions = [
        f"Payment for invoice #{random.randint(1000, 9999)}",
        f"Wire transfer - {receiver.get('account_name', 'Unknown')}",
        f"Business payment",
        f"Investment transfer",
        f"Property payment - partial",
        f"Consulting services",
        f"Equipment purchase",
        f"Salary payment",
        f"Vendor payment",
        f"International trade settlement",
        f"Loan repayment",
        f"Service fee",
        f"Commission payment",
        f"Refund processing",
        f"Monthly subscription"
    ]
    
    if amount > 50000:
        descriptions.extend([
            f"Real estate transaction",
            f"Vehicle purchase - {random.choice(['BMW', 'Mercedes', 'Audi', 'Tesla'])}",
            f"Business acquisition payment {random.randint(1, 5)}/5",
            f"Capital investment"
        ])
    
    return random.choice(descriptions)

async def create_customer(session: requests.Session, customer_data: Dict):
    """Create a customer via API"""
    try:
        response = session.post(
            f"{API_BASE_URL}/customers",
            json=customer_data,
            timeout=5
        )
        if response.status_code in [200, 201]:
            stats["customers_created"] += 1
            return True
        else:
            print(f"Failed to create customer: {response.status_code}")
            return False
    except Exception as e:
        stats["errors"] += 1
        print(f"Error creating customer: {e}")
        return False

async def create_transaction(session: requests.Session, transaction_data: Dict):
    """Create a transaction via API"""
    try:
        response = session.post(
            f"{API_BASE_URL}/transactions",
            json=transaction_data,
            timeout=5
        )
        if response.status_code in [200, 201]:
            stats["total_transactions"] += 1
            return True
        else:
            print(f"Failed to create transaction: {response.status_code}")
            return False
    except Exception as e:
        stats["errors"] += 1
        print(f"Error creating transaction: {e}")
        return False

async def continuous_population():
    """Main loop for continuous database population"""
    print("="*50)
    print("AML DATABASE CONTINUOUS POPULATION")
    print("="*50)
    print(f"API Endpoint: {API_BASE_URL}")
    print("Press Ctrl+C to stop")
    print("="*50)
    print()
    
    session = requests.Session()
    
    # Initial setup - create some customers
    print("Creating initial customer base...")
    customers = []
    for i in range(50):  # Create 50 initial customers
        customer = generate_customer()
        customers.append(customer)
        await create_customer(session, customer)
        if (i + 1) % 10 == 0:
            print(f"  Created {i + 1} customers...")
    
    print(f"✓ Initial setup complete: {len(customers)} customers created\n")
    
    transaction_id = 1
    last_stats_print = time.time()
    
    # Main loop
    print("Starting continuous transaction generation...")
    while True:
        try:
            # Generate 1-5 transactions per cycle
            num_transactions = random.randint(1, 5)
            
            for _ in range(num_transactions):
                # Occasionally add new customers (10% chance)
                if random.random() < 0.1 and len(customers) < 200:
                    new_customer = generate_customer()
                    customers.append(new_customer)
                    await create_customer(session, new_customer)
                
                # Generate and create transaction
                transaction = generate_transaction(customers, transaction_id)
                await create_transaction(session, transaction)
                transaction_id += 1
                
                # Show progress
                if transaction["is_suspicious"]:
                    print(f"⚠️  Suspicious: TXN-{transaction_id-1:08d} | "
                          f"{transaction['sender_name'][:20]} → {transaction['receiver_name'][:20]} | "
                          f"${transaction['amount']:,.2f} | Risk: {transaction['risk_score']}")
                elif stats["total_transactions"] % 10 == 0:
                    print(f"✓ Created {stats['total_transactions']} transactions...")
            
            # Print statistics every 30 seconds
            if time.time() - last_stats_print > 30:
                print_statistics()
                last_stats_print = time.time()
            
            # Wait between batches (simulate real-time flow)
            await asyncio.sleep(random.uniform(0.5, 3))
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error in main loop: {e}")
            stats["errors"] += 1
            await asyncio.sleep(5)  # Wait before retrying

def main():
    """Entry point"""
    try:
        # Check if API is accessible
        print("Checking API connectivity...")
        response = requests.get(f"{API_BASE_URL.replace('/api/v1', '')}/health", timeout=5)
        if response.status_code == 200:
            print("✓ API is accessible\n")
        else:
            print(f"⚠️  API returned status {response.status_code}")
    except Exception as e:
        print(f"⚠️  Warning: Could not reach API at {API_BASE_URL}")
        print(f"   Error: {e}")
        print("   Make sure the backend is running!")
        print()
        response = input("Continue anyway? (y/n): ")
        if response.lower() != 'y':
            return
    
    # Run the async loop
    asyncio.run(continuous_population())

if __name__ == "__main__":
    main()