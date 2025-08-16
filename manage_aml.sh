#!/bin/bash

# AML System Management Script
# This script manages only AML containers without affecting other services

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# List of AML container names
AML_CONTAINERS="aml-backend aml-frontend aml-postgres aml-redis aml-nginx"

function show_status() {
    echo -e "${YELLOW}AML System Status:${NC}"
    echo "----------------------------------------"
    
    # Check each AML container
    for container in $AML_CONTAINERS; do
        if docker ps | grep -q "$container"; then
            echo -e "${GREEN}✓${NC} $container is running"
            docker ps --format "  {{.Ports}}" --filter "name=$container"
        else
            if docker ps -a | grep -q "$container"; then
                echo -e "${RED}✗${NC} $container is stopped"
            fi
        fi
    done
    
    echo ""
    echo "Other services running on this server:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v -E "aml-|NAMES"
}

function start_aml() {
    echo -e "${YELLOW}Starting AML System...${NC}"
    
    # Check if simple deployment exists
    if [ -f "docker-compose.simple.yml" ]; then
        docker-compose -f docker-compose.simple.yml up -d
    elif [ -f "docker-compose.targeted.yml" ]; then
        docker-compose -f docker-compose.targeted.yml up -d
    else
        docker start aml-backend aml-frontend 2>/dev/null
    fi
    
    echo -e "${GREEN}AML System started!${NC}"
}

function stop_aml() {
    echo -e "${YELLOW}Stopping AML System...${NC}"
    
    for container in $AML_CONTAINERS; do
        if docker ps | grep -q "$container"; then
            echo "Stopping $container..."
            docker stop "$container"
        fi
    done
    
    echo -e "${GREEN}AML System stopped!${NC}"
}

function restart_aml() {
    echo -e "${YELLOW}Restarting AML System...${NC}"
    stop_aml
    sleep 2
    start_aml
}

function logs_aml() {
    container=${2:-aml-backend}
    echo -e "${YELLOW}Showing logs for $container:${NC}"
    docker logs -f "$container"
}

function test_aml() {
    echo -e "${YELLOW}Testing AML System...${NC}"
    
    # Test backend health
    echo -n "Backend health check: "
    if curl -s http://localhost:50000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Healthy${NC}"
    else
        echo -e "${RED}✗ Not responding${NC}"
    fi
    
    # Test authentication
    echo -n "Authentication test: "
    response=$(curl -s -X POST http://localhost:50000/api/v1/auth/login \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=admin@test.com&password=admin123" 2>/dev/null)
    
    if echo "$response" | grep -q "access_token"; then
        echo -e "${GREEN}✓ Working${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    # Test frontend
    echo -n "Frontend check: "
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Accessible${NC}"
    else
        echo -e "${RED}✗ Not accessible${NC}"
    fi
}

function cleanup_aml() {
    echo -e "${YELLOW}Cleaning up AML containers and images...${NC}"
    
    # Stop and remove AML containers
    for container in $AML_CONTAINERS; do
        docker stop "$container" 2>/dev/null
        docker rm "$container" 2>/dev/null
    done
    
    # Remove AML images
    docker images | grep "aml-" | awk '{print $3}' | xargs docker rmi -f 2>/dev/null
    
    echo -e "${GREEN}Cleanup complete!${NC}"
}

# Main menu
case "$1" in
    start)
        start_aml
        ;;
    stop)
        stop_aml
        ;;
    restart)
        restart_aml
        ;;
    status)
        show_status
        ;;
    logs)
        logs_aml "$@"
        ;;
    test)
        test_aml
        ;;
    cleanup)
        cleanup_aml
        ;;
    *)
        echo "AML System Management"
        echo "Usage: $0 {start|stop|restart|status|logs|test|cleanup}"
        echo ""
        echo "Commands:"
        echo "  start    - Start AML services"
        echo "  stop     - Stop AML services" 
        echo "  restart  - Restart AML services"
        echo "  status   - Show status of all services"
        echo "  logs     - Show logs (default: aml-backend)"
        echo "  test     - Test AML endpoints"
        echo "  cleanup  - Remove AML containers and images"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 logs aml-frontend"
        echo "  $0 restart"
        ;;
esac