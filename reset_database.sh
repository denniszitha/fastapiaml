#!/bin/bash

echo "========================================="
echo "Database Reset Script"
echo "========================================="

DB_PASSWORD=${DB_PASSWORD:-aml_password}

echo ""
echo "WARNING: This will reset the entire database!"
echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
sleep 5

echo ""
echo "Step 1: Connecting to PostgreSQL and resetting database..."
echo "----------------------------------------------------------"

# Execute the reset SQL script
docker exec -i aml-postgres psql -U postgres << EOF
-- Drop the database if it exists
DROP DATABASE IF EXISTS aml_database;

-- Drop the user if it exists
DROP USER IF EXISTS aml_user;

-- Recreate user and database
CREATE USER aml_user WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE aml_database OWNER aml_user;
GRANT ALL PRIVILEGES ON DATABASE aml_database TO aml_user;

-- Connect to the new database
\c aml_database;

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO aml_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO aml_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO aml_user;

-- Show current state
\l
\du
EOF

echo ""
echo "Step 2: Restarting backend to apply changes..."
echo "----------------------------------------------"
docker restart aml-backend

echo ""
echo "Step 3: Waiting for backend to initialize..."
echo "--------------------------------------------"
sleep 10

echo ""
echo "Step 4: Checking backend status..."
echo "----------------------------------"
docker logs aml-backend --tail 20

echo ""
echo "Step 5: Testing health endpoint..."
echo "----------------------------------"
curl -s http://localhost:50000/health | python3 -m json.tool || echo "Health check failed"

echo ""
echo "Step 6: Creating test user..."
echo "----------------------------"
curl -X POST http://localhost:50000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "admin123",
    "name": "Admin User"
  }' 2>/dev/null | python3 -m json.tool || echo "User creation failed"

echo ""
echo "========================================="
echo "Database Reset Complete!"
echo "========================================="
echo ""
echo "The database has been completely reset."
echo "All enum types and tables have been recreated."
echo ""