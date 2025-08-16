#!/bin/bash

echo "========================================="
echo "Quick Fix for Enum Type Conflicts"
echo "========================================="

echo ""
echo "Step 1: Executing database enum fix..."
echo "--------------------------------------"

# Fix enum types directly in the database
docker exec -i aml-postgres psql -U postgres -d aml_database << 'EOF' 2>&1 | grep -v "NOTICE"
-- Drop all dependent tables first
DROP TABLE IF EXISTS transaction_limits CASCADE;
DROP TABLE IF EXISTS exemptions CASCADE;
DROP TABLE IF EXISTS watchlist CASCADE;
DROP TABLE IF EXISTS customer_profiles CASCADE;
DROP TABLE IF EXISTS suspicious_cases CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop existing enum types
DROP TYPE IF EXISTS transactionstatus CASCADE;
DROP TYPE IF EXISTS riskrating CASCADE;
DROP TYPE IF EXISTS casestatus CASCADE;
DROP TYPE IF EXISTS limittype CASCADE;

-- Show clean state
SELECT 'Database cleaned' as status;
EOF

echo ""
echo "Step 2: Restarting backend with clean database..."
echo "-------------------------------------------------"
docker restart aml-backend

echo ""
echo "Step 3: Waiting for backend to recreate schema..."
echo "-------------------------------------------------"
for i in {1..15}; do
    echo -n "."
    sleep 1
done
echo ""

echo ""
echo "Step 4: Checking backend health..."
echo "----------------------------------"
if curl -s http://localhost:50000/health > /dev/null 2>&1; then
    echo "✓ Backend is healthy!"
    curl -s http://localhost:50000/health | python3 -m json.tool
else
    echo "✗ Backend health check failed"
    echo "Checking logs..."
    docker logs aml-backend --tail 15
fi

echo ""
echo "Step 5: Verifying database schema..."
echo "------------------------------------"
docker exec aml-postgres psql -U postgres -d aml_database -c "\dt" 2>/dev/null | head -20
docker exec aml-postgres psql -U postgres -d aml_database -c "\dT+" 2>/dev/null | head -20

echo ""
echo "========================================="
echo "Quick Fix Complete!"
echo "========================================="
echo ""
echo "Test the application at:"
echo "  http://102.23.120.243:50000/health"
echo "  http://102.23.120.243:50000/docs"
echo ""