#!/bin/bash

echo "========================================="
echo "Project Cleanup Script"
echo "========================================="
echo ""
echo "This script will remove unnecessary files from the project"
echo "Files to be removed:"
echo "  - Temporary deployment scripts"
echo "  - Python cache files"
echo "  - Duplicate/backup files"
echo "  - Test files"
echo "  - Old docker-compose variants"
echo ""
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

echo ""
echo "Step 1: Removing Python cache files..."
echo "--------------------------------------"
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find . -type f -name "*.pyc" -delete 2>/dev/null
find . -type f -name "*.pyo" -delete 2>/dev/null
find . -type f -name "*.pyd" -delete 2>/dev/null
find . -type f -name ".DS_Store" -delete 2>/dev/null
find . -type f -name "*.swp" -delete 2>/dev/null
find . -type f -name "*.swo" -delete 2>/dev/null
find . -type f -name "*~" -delete 2>/dev/null
echo "✓ Python cache files removed"

echo ""
echo "Step 2: Removing temporary deployment scripts..."
echo "-----------------------------------------------"
# Keep only the main deployment scripts
SCRIPTS_TO_REMOVE=(
    "deploy_102.23.120.243.sh"
    "deploy_backend_fix.sh"
    "deploy_exemptions_fix.sh"
    "deploy_fix_cors.sh"
    "deploy_fixed.sh"
    "deploy_network_fix.sh"
    "deploy_postgres.sh"
    "deploy_postgres_fixed.sh"
    "deploy_simple_fix.sh"
    "deploy_standalone.sh"
    "deploy_targeted.sh"
    "deploy_working.sh"
    "fix_auth_connection.sh"
    "fix_frontend.sh"
    "fix_frontend_complete.sh"
    "quick_fix.sh"
    "quick_frontend_fix.sh"
    "quick_nginx_fix.sh"
)

for script in "${SCRIPTS_TO_REMOVE[@]}"; do
    if [ -f "$script" ]; then
        rm "$script"
        echo "  Removed: $script"
    fi
done

echo ""
echo "Step 3: Removing duplicate docker-compose files..."
echo "-------------------------------------------------"
# Keep only the main docker-compose.yml and production version
COMPOSE_TO_REMOVE=(
    "docker-compose.102.23.120.243.yml"
    "docker-compose.override.yml"
    "docker-compose.simple.yml"
    "docker-compose.sqlite.yml"
    "docker-compose.targeted.yml"
)

for compose in "${COMPOSE_TO_REMOVE[@]}"; do
    if [ -f "$compose" ]; then
        rm "$compose"
        echo "  Removed: $compose"
    fi
done

echo ""
echo "Step 4: Removing test and temporary files..."
echo "-------------------------------------------"
TEST_FILES=(
    "test_auth.py"
    "test_cors.py"
    "test_cors_simple.html"
    "aml_database.db"
    "fix_db_enums.sql"
)

for test_file in "${TEST_FILES[@]}"; do
    if [ -f "$test_file" ]; then
        rm "$test_file"
        echo "  Removed: $test_file"
    fi
done

echo ""
echo "Step 5: Removing backup and duplicate app files..."
echo "-------------------------------------------------"
BACKUP_FILES=(
    "app/main_backup.py"
    "app/main_fixed.py"
    "app/main_simple_cors.py"
    "app/main_standalone.py"
    "app/core/database_config.py"
    "app/core/postgres_config.py"
    "app/core/simple_db_config.py"
    "app/middleware/cors_handler.py"
    "app/middleware/cors_middleware.py"
    "app/api/endpoints/auth_enhanced.py"
    "app/api/endpoints/simple_statistics.py"
    "Dockerfile.backend"
    "Dockerfile.simple"
)

for backup in "${BACKUP_FILES[@]}"; do
    if [ -f "$backup" ]; then
        rm "$backup"
        echo "  Removed: $backup"
    fi
done

echo ""
echo "Step 6: Removing unnecessary documentation..."
echo "--------------------------------------------"
DOCS_TO_REMOVE=(
    "CORS_TROUBLESHOOTING.md"
    "DEPLOYMENT_FULL.md"
    "EMERGENCY_CORS_FIX.md"
    "PORT_CONFIGURATION.md"
    "PUSH_TO_GITHUB.md"
)

for doc in "${DOCS_TO_REMOVE[@]}"; do
    if [ -f "$doc" ]; then
        rm "$doc"
        echo "  Removed: $doc"
    fi
done

echo ""
echo "Step 7: Cleaning nginx configuration..."
echo "--------------------------------------"
# Remove duplicate nginx configs, keep only the working one
NGINX_TO_REMOVE=(
    "nginx/nginx-production.conf"
    "nginx/nginx.102.23.120.243.conf"
    "nginx/default.conf"
    "aml-frontend/nginx.conf"
)

for nginx_conf in "${NGINX_TO_REMOVE[@]}"; do
    if [ -f "$nginx_conf" ]; then
        rm "$nginx_conf"
        echo "  Removed: $nginx_conf"
    fi
done

echo ""
echo "Step 8: Removing node_modules build artifacts..."
echo "-----------------------------------------------"
# Clean build directories but not node_modules (needed for development)
if [ -d "aml-frontend/build" ]; then
    echo "  Keeping build directory (needed for deployment)"
fi

# Remove log files from node_modules
find aml-frontend/node_modules -name "*.log" -delete 2>/dev/null
echo "✓ Log files removed from node_modules"

echo ""
echo "Step 9: Creating .gitignore if missing..."
echo "-----------------------------------------"
if [ ! -f ".gitignore" ]; then
    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
.venv

# JavaScript/React
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnp
.pnp.js

# Build outputs
build/
dist/
*.egg-info/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Database
*.db
*.sqlite
*.sqlite3

# Logs
*.log
logs/

# Docker volumes
postgres-data/
redis-data/

# Temporary files
tmp/
temp/
*.tmp
*.bak
*.backup

# SSL certificates (except self-signed for development)
*.pem
*.key
*.crt
!nginx/ssl/.gitkeep
EOF
    echo "✓ Created .gitignore"
else
    echo "✓ .gitignore already exists"
fi

echo ""
echo "Step 10: Summary of cleanup..."
echo "-----------------------------"
# Count remaining files
TOTAL_FILES=$(find . -type f -not -path "./.git/*" -not -path "./node_modules/*" | wc -l)
echo "Files remaining in project: $TOTAL_FILES"

echo ""
echo "========================================="
echo "Cleanup Complete!"
echo "========================================="
echo ""
echo "The following have been kept:"
echo "  ✓ Main application code (app/)"
echo "  ✓ Frontend source (aml-frontend/src/)"
echo "  ✓ Essential configurations"
echo "  ✓ docker-compose.yml and docker-compose.production.yml"
echo "  ✓ requirements.txt"
echo "  ✓ README.md and DEPLOYMENT.md"
echo "  ✓ Deploy scripts in deploy/ directory"
echo ""
echo "Next steps:"
echo "  1. Review changes: git status"
echo "  2. Add to git: git add -A"
echo "  3. Commit: git commit -m 'Clean up project files'"
echo "  4. Push: git push origin main"
echo ""