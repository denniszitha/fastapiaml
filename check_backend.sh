#!/bin/bash

echo "========================================="
echo "Backend Diagnostic Script"
echo "========================================="

echo ""
echo "1. Checking if backend container is running..."
docker ps | grep aml-backend && echo "✓ Backend container is running" || echo "✗ Backend container not found"

echo ""
echo "2. Checking backend logs..."
echo "----------------------------------------"
docker logs aml-backend --tail 20 2>&1

echo ""
echo "3. Testing backend health endpoint..."
echo "----------------------------------------"
curl -v http://localhost:50000/health 2>&1 | head -20

echo ""
echo "4. Testing backend from inside container..."
echo "----------------------------------------"
docker exec aml-backend curl -s http://localhost:8000/health 2>&1

echo ""
echo "5. Checking network connectivity..."
echo "----------------------------------------"
docker exec aml-backend ping -c 2 aml-postgres 2>&1 || echo "Cannot ping postgres"

echo ""
echo "6. Checking database connection..."
echo "----------------------------------------"
docker exec aml-postgres psql -U postgres -d aml_database -c "SELECT current_database(), current_user;" 2>&1

echo ""
echo "7. Checking port bindings..."
echo "----------------------------------------"
netstat -tlnp 2>/dev/null | grep -E ":(50000|8080|5433|6380)" || ss -tlnp | grep -E ":(50000|8080|5433|6380)"

echo ""
echo "8. Testing backend API docs..."
echo "----------------------------------------"
curl -s http://localhost:50000/docs | head -10

echo ""
echo "========================================="
echo "Diagnostic complete"
echo "========================================="