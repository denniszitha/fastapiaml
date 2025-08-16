#!/bin/bash

# ============================================
# AML SYSTEM MANAGEMENT SCRIPT
# ============================================
# Simple management commands for the deployed system
# ============================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get public IP
PUBLIC_IP=${PUBLIC_IP:-$(curl -s http://checkip.amazonaws.com || echo "localhost")}
FRONTEND_PORT=8888
BACKEND_PORT=8000

show_menu() {
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}AML MONITORING SYSTEM - MANAGEMENT${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "1)  Start all services"
    echo "2)  Stop all services"
    echo "3)  Restart all services"
    echo "4)  View status"
    echo "5)  View logs (all)"
    echo "6)  View backend logs"
    echo "7)  View frontend logs"
    echo "8)  View database logs"
    echo "9)  Populate database with test data"
    echo "10) Backup database"
    echo "11) Clean all (remove containers and volumes)"
    echo "12) Show access URLs"
    echo "0)  Exit"
    echo ""
}

start_services() {
    echo -e "${GREEN}Starting all services...${NC}"
    sudo docker start postgres redis aml-backend aml-frontend 2>/dev/null || {
        echo -e "${YELLOW}Some services not found. Running full deployment...${NC}"
        ./deploy_production.sh
    }
    echo -e "${GREEN}✓ Services started${NC}"
}

stop_services() {
    echo -e "${YELLOW}Stopping all services...${NC}"
    sudo docker stop aml-frontend aml-backend postgres redis 2>/dev/null || true
    echo -e "${GREEN}✓ Services stopped${NC}"
}

restart_services() {
    echo -e "${YELLOW}Restarting all services...${NC}"
    stop_services
    sleep 2
    start_services
    echo -e "${GREEN}✓ Services restarted${NC}"
}

view_status() {
    echo -e "${BLUE}Service Status:${NC}"
    echo "----------------------------------------"
    sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|aml-|postgres|redis" || echo "No services running"
    
    echo ""
    echo -e "${BLUE}Resource Usage:${NC}"
    echo "----------------------------------------"
    sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(sudo docker ps -q --filter "name=aml-" --filter "name=postgres" --filter "name=redis") 2>/dev/null || echo "No services running"
}

view_logs() {
    case $1 in
        "backend")
            echo -e "${BLUE}Backend Logs:${NC}"
            sudo docker logs aml-backend --tail 50 -f
            ;;
        "frontend")
            echo -e "${BLUE}Frontend Logs:${NC}"
            sudo docker logs aml-frontend --tail 50 -f
            ;;
        "database")
            echo -e "${BLUE}Database Logs:${NC}"
            sudo docker logs postgres --tail 50 -f
            ;;
        *)
            echo -e "${BLUE}All Service Logs (last 20 lines each):${NC}"
            echo ""
            echo "=== BACKEND ==="
            sudo docker logs aml-backend --tail 20 2>/dev/null || echo "Backend not running"
            echo ""
            echo "=== FRONTEND ==="
            sudo docker logs aml-frontend --tail 20 2>/dev/null || echo "Frontend not running"
            echo ""
            echo "=== DATABASE ==="
            sudo docker logs postgres --tail 20 2>/dev/null || echo "Database not running"
            echo ""
            echo "=== REDIS ==="
            sudo docker logs redis --tail 20 2>/dev/null || echo "Redis not running"
            ;;
    esac
}

populate_database() {
    echo -e "${GREEN}Populating database with test data...${NC}"
    if [ -f "./populate_docker_db.sh" ]; then
        ./populate_docker_db.sh
    else
        echo -e "${RED}populate_docker_db.sh not found!${NC}"
        echo "Creating basic test data..."
        
        # Basic population directly via SQL
        sudo docker exec postgres psql -U aml_user -d aml_monitoring << 'EOF'
-- Add test customer profiles
INSERT INTO customer_profiles (account_number, account_name, customer_type, risk_level, country)
VALUES 
  ('1234-567890', 'John Smith', 'INDIVIDUAL', 'LOW', 'USA'),
  ('2345-678901', 'Global Trade Corp', 'CORPORATE', 'MEDIUM', 'UK'),
  ('3456-789012', 'Maria Garcia', 'INDIVIDUAL', 'HIGH', 'Mexico')
ON CONFLICT DO NOTHING;

-- Add test watchlist entries
INSERT INTO watchlist (account_number, account_name, reason, risk_level, added_by)
VALUES 
  ('9999-888888', 'Suspicious Co', 'Under investigation', 'CRITICAL', 'System')
ON CONFLICT DO NOTHING;

-- Add test suspicious cases
INSERT INTO suspicious_cases (case_number, account_number, account_name, transaction_amount, risk_score, alert_reason)
VALUES 
  ('SAR-2024-00001', '1234-567890', 'John Smith', 50000, 75.5, 'Large cash deposit')
ON CONFLICT DO NOTHING;

SELECT 'Test data inserted successfully' as status;
EOF
    fi
    echo -e "${GREEN}✓ Database populated${NC}"
}

backup_database() {
    BACKUP_FILE="aml_backup_$(date +%Y%m%d_%H%M%S).sql"
    echo -e "${GREEN}Creating database backup: $BACKUP_FILE${NC}"
    sudo docker exec postgres pg_dump -U aml_user aml_monitoring > $BACKUP_FILE
    echo -e "${GREEN}✓ Backup saved to: $(pwd)/$BACKUP_FILE${NC}"
}

clean_all() {
    echo -e "${RED}WARNING: This will remove all containers and data!${NC}"
    read -p "Are you sure? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing all containers and volumes...${NC}"
        sudo docker rm -f aml-frontend aml-backend postgres redis 2>/dev/null || true
        sudo docker volume rm postgres-data redis-data 2>/dev/null || true
        sudo docker network rm aml-network 2>/dev/null || true
        echo -e "${GREEN}✓ Cleanup complete${NC}"
    else
        echo "Cleanup cancelled"
    fi
}

show_urls() {
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}ACCESS URLS${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${BLUE}Frontend Application:${NC}"
    echo "  Local: http://localhost:$FRONTEND_PORT"
    echo "  Public: http://$PUBLIC_IP:$FRONTEND_PORT"
    echo ""
    echo -e "${BLUE}Backend API:${NC}"
    echo "  Local: http://localhost:$BACKEND_PORT"
    echo "  Public: http://$PUBLIC_IP:$BACKEND_PORT"
    echo ""
    echo -e "${BLUE}API Documentation:${NC}"
    echo "  Local: http://localhost:$BACKEND_PORT/docs"
    echo "  Public: http://$PUBLIC_IP:$BACKEND_PORT/docs"
    echo ""
    echo -e "${BLUE}Default Credentials:${NC}"
    echo "  Username: admin"
    echo "  Password: admin123"
    echo ""
    echo -e "${GREEN}============================================${NC}"
}

# Main loop
while true; do
    show_menu
    read -p "Select option: " choice
    echo ""
    
    case $choice in
        1)
            start_services
            ;;
        2)
            stop_services
            ;;
        3)
            restart_services
            ;;
        4)
            view_status
            ;;
        5)
            view_logs "all"
            ;;
        6)
            view_logs "backend"
            ;;
        7)
            view_logs "frontend"
            ;;
        8)
            view_logs "database"
            ;;
        9)
            populate_database
            ;;
        10)
            backup_database
            ;;
        11)
            clean_all
            ;;
        12)
            show_urls
            ;;
        0)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done