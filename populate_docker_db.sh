#!/bin/bash

echo "========================================="
echo "Docker Database Population Script"
echo "========================================="
echo ""
echo "This script populates the AML database with test data"
echo "It works with the Docker containers directly"
echo ""

# Check if containers are running
echo "Step 1: Checking Docker containers..."
echo "-------------------------------------"

BACKEND_RUNNING=$(sudo docker ps --format "{{.Names}}" | grep -E "aml-backend|backend" | head -1)
DB_RUNNING=$(sudo docker ps --format "{{.Names}}" | grep -E "postgres|aml-postgres|database" | head -1)

if [ -z "$BACKEND_RUNNING" ]; then
    echo "✗ Backend container not found!"
    echo "  Please run: docker-compose up -d"
    exit 1
else
    echo "✓ Backend container: $BACKEND_RUNNING"
fi

if [ -z "$DB_RUNNING" ]; then
    echo "✗ Database container not found!"
    echo "  Please run: docker-compose up -d"
    exit 1
else
    echo "✓ Database container: $DB_RUNNING"
fi

echo ""
echo "Step 2: Installing Python dependencies in container..."
echo "------------------------------------------------------"

# Create a temporary Python script for database population
cat > /tmp/populate_aml_db.py << 'PYTHON_SCRIPT'
import psycopg2
import random
from datetime import datetime, timedelta
import uuid
import time

# Database connection
DB_CONFIG = {
    'host': 'postgres',  # Docker service name
    'port': 5432,
    'database': 'aml_monitoring',
    'user': 'aml_user',
    'password': 'secure_password'
}

# Try alternative hosts if first fails
HOSTS_TO_TRY = ['postgres', 'aml-postgres', 'localhost', '172.17.0.1']

conn = None
for host in HOSTS_TO_TRY:
    try:
        DB_CONFIG['host'] = host
        conn = psycopg2.connect(**DB_CONFIG)
        print(f"✓ Connected to database via {host}")
        break
    except:
        continue

if not conn:
    print("✗ Could not connect to database")
    exit(1)

cur = conn.cursor()

# Sample data
NAMES = ["John Smith", "Maria Garcia", "Li Wei", "Ahmed Hassan", "Sarah Johnson",
         "Emma Wilson", "James Brown", "Fatima Al-Said", "Global Trade Corp", 
         "Tech Solutions Inc", "Import Export Ltd", "International Finance LLC"]

COUNTRIES = ["USA", "UK", "Canada", "UAE", "Singapore", "Nigeria", "Kenya", 
             "Germany", "France", "Japan", "Brazil", "India"]

HIGH_RISK_COUNTRIES = ["Iran", "Syria", "North Korea", "Afghanistan"]

print("\nPopulating database with test data...")
print("=" * 40)

# 1. Add Customer Profiles
print("\n1. Creating customer profiles...")
for i in range(20):
    account_number = f"{random.randint(1000,9999)}-{random.randint(100000,999999)}"
    name = random.choice(NAMES)
    customer_type = "CORPORATE" if "Corp" in name or "Inc" in name or "Ltd" in name or "LLC" in name else "INDIVIDUAL"
    risk_level = random.choice(["LOW", "LOW", "MEDIUM", "HIGH", "CRITICAL"])
    
    try:
        cur.execute("""
            INSERT INTO customer_profiles 
            (account_number, account_name, customer_type, risk_level, country, 
             is_pep, is_sanctioned, kyc_verified, account_balance, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (account_number) DO NOTHING
        """, (
            account_number, name, customer_type, risk_level, 
            random.choice(COUNTRIES), 
            random.random() < 0.05,  # 5% PEP
            False,  # Not sanctioned
            random.random() < 0.95,  # 95% KYC verified
            round(random.uniform(1000, 1000000), 2),
            datetime.now() - timedelta(days=random.randint(1, 365))
        ))
        if cur.rowcount > 0:
            print(f"  ✓ Created profile: {name} ({account_number})")
    except Exception as e:
        print(f"  ⚠ Error creating profile: {e}")

conn.commit()

# 2. Add Watchlist Entries
print("\n2. Adding watchlist entries...")
for i in range(10):
    account_number = f"{random.randint(1000,9999)}-{random.randint(100000,999999)}"
    name = random.choice(NAMES)
    
    try:
        cur.execute("""
            INSERT INTO watchlist 
            (account_number, account_name, reason, risk_level, added_by, is_active, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (account_number) DO NOTHING
        """, (
            account_number, name,
            random.choice([
                "Suspicious activity detected",
                "PEP - Politically Exposed Person",
                "High-risk jurisdiction",
                "Under investigation",
                "Pattern matching alert"
            ]),
            random.choice(["HIGH", "CRITICAL"]),
            "System Admin",
            True,
            datetime.now() - timedelta(days=random.randint(1, 30))
        ))
        if cur.rowcount > 0:
            print(f"  ✓ Added to watchlist: {name}")
    except Exception as e:
        print(f"  ⚠ Error adding to watchlist: {e}")

conn.commit()

# 3. Add Transaction Exemptions
print("\n3. Creating transaction exemptions...")
for i in range(8):
    account_number = f"{random.randint(1000,9999)}-{random.randint(100000,999999)}"
    name = random.choice(["Government Treasury", "Embassy Account", "Charity Foundation", "Internal Transfer Account"])
    
    try:
        cur.execute("""
            INSERT INTO transaction_exemptions 
            (account_number, account_name, exemption_type, reason, start_date, 
             end_date, approved_by, is_active, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (account_number) DO NOTHING
        """, (
            account_number, name,
            random.choice(["temporary", "permanent", "conditional"]),
            random.choice([
                "Government account",
                "Verified charity organization",
                "Embassy account",
                "Internal transfer account"
            ]),
            datetime.now(),
            datetime.now() + timedelta(days=random.randint(30, 365)) if random.random() > 0.3 else None,
            "Compliance Officer",
            True,
            datetime.now()
        ))
        if cur.rowcount > 0:
            print(f"  ✓ Added exemption: {name}")
    except Exception as e:
        print(f"  ⚠ Error adding exemption: {e}")

conn.commit()

# 4. Add Transaction Limits
print("\n4. Setting transaction limits...")
limit_types = [
    ("daily", "INDIVIDUAL", 1000, 50000),
    ("daily", "CORPORATE", 10000, 500000),
    ("monthly", "INDIVIDUAL", 10000, 200000),
    ("monthly", "CORPORATE", 100000, 5000000),
    ("per_transaction", "ALL", 100, 100000)
]

for limit_type, customer_type, min_amt, max_amt in limit_types:
    try:
        cur.execute("""
            INSERT INTO transaction_limits 
            (limit_type, currency, min_amount, max_amount, customer_type, is_active, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """, (
            limit_type, "USD", min_amt, max_amt, customer_type, True, datetime.now()
        ))
        if cur.rowcount > 0:
            print(f"  ✓ Set {limit_type} limit for {customer_type}: ${min_amt:,} - ${max_amt:,}")
    except Exception as e:
        print(f"  ⚠ Error setting limit: {e}")

conn.commit()

# 5. Create Suspicious Cases
print("\n5. Generating suspicious cases...")
for i in range(15):
    case_number = f"SAR-{datetime.now().year}-{random.randint(10000, 99999)}"
    account_number = f"{random.randint(1000,9999)}-{random.randint(100000,999999)}"
    
    try:
        cur.execute("""
            INSERT INTO suspicious_cases 
            (case_number, account_number, account_name, transaction_amount, 
             risk_score, alert_reason, status, assigned_to, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (case_number) DO NOTHING
        """, (
            case_number,
            account_number,
            random.choice(NAMES),
            round(random.uniform(10000, 500000), 2),
            round(random.uniform(60, 100), 2),
            random.choice([
                "Large cash deposit",
                "Rapid movement of funds",
                "Transaction to high-risk country",
                "Structuring pattern detected",
                "Unusual transaction pattern"
            ]),
            random.choice(["PENDING", "UNDER_REVIEW", "ESCALATED", "CLOSED"]),
            random.choice(["Analyst1", "Analyst2", "Senior Analyst"]),
            datetime.now() - timedelta(days=random.randint(0, 30))
        ))
        if cur.rowcount > 0:
            print(f"  ✓ Created case: {case_number}")
    except Exception as e:
        print(f"  ⚠ Error creating case: {e}")

conn.commit()

# Summary
cur.execute("SELECT COUNT(*) FROM customer_profiles")
profiles_count = cur.fetchone()[0]

cur.execute("SELECT COUNT(*) FROM watchlist WHERE is_active = true")
watchlist_count = cur.fetchone()[0]

cur.execute("SELECT COUNT(*) FROM transaction_exemptions WHERE is_active = true")
exemptions_count = cur.fetchone()[0]

cur.execute("SELECT COUNT(*) FROM transaction_limits WHERE is_active = true")
limits_count = cur.fetchone()[0]

cur.execute("SELECT COUNT(*) FROM suspicious_cases")
cases_count = cur.fetchone()[0]

print("\n" + "=" * 40)
print("Database Population Complete!")
print("=" * 40)
print(f"Customer Profiles: {profiles_count}")
print(f"Watchlist Entries: {watchlist_count}")
print(f"Exemptions: {exemptions_count}")
print(f"Transaction Limits: {limits_count}")
print(f"Suspicious Cases: {cases_count}")
print("=" * 40)

cur.close()
conn.close()
PYTHON_SCRIPT

echo ""
echo "Step 3: Running population script in backend container..."
echo "--------------------------------------------------------"

# Copy script to backend container and run it
sudo docker cp /tmp/populate_aml_db.py $BACKEND_RUNNING:/tmp/populate_aml_db.py

# Install psycopg2 if needed and run the script
sudo docker exec $BACKEND_RUNNING sh -c "pip install psycopg2-binary 2>/dev/null || true && python /tmp/populate_aml_db.py"

echo ""
echo "Step 4: Cleaning up..."
echo "---------------------"
rm -f /tmp/populate_aml_db.py
sudo docker exec $BACKEND_RUNNING rm -f /tmp/populate_aml_db.py

echo ""
echo "========================================="
echo "Database Population Complete!"
echo "========================================="
echo ""
echo "The AML database has been populated with test data."
echo "You can now use the application with realistic data."
echo ""
echo "To verify the data:"
echo "  1. Access the web interface"
echo "  2. Check the dashboard for statistics"
echo "  3. View watchlist, exemptions, and cases"
echo ""