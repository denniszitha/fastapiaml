"""
PostgreSQL-only database configuration
"""
import os
import time
import logging
from sqlalchemy import create_engine, text

logger = logging.getLogger(__name__)

def wait_for_postgres(database_url, max_retries=30):
    """
    Wait for PostgreSQL to be ready
    """
    for i in range(max_retries):
        try:
            engine = create_engine(
                database_url, 
                pool_pre_ping=True,
                connect_args={"connect_timeout": 3}
            )
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
                conn.commit()
            logger.info(f"PostgreSQL is ready (attempt {i+1})")
            return True
        except Exception as e:
            if i < max_retries - 1:
                logger.info(f"Waiting for PostgreSQL... (attempt {i+1}/{max_retries})")
                time.sleep(2)
            else:
                logger.error(f"PostgreSQL connection failed after {max_retries} attempts: {str(e)}")
                return False
    return False

def get_database_url():
    """
    Get PostgreSQL database URL with retries
    """
    # Priority 1: Explicit DATABASE_URL from environment
    if os.getenv("DATABASE_URL"):
        database_url = os.getenv("DATABASE_URL")
        logger.info("Using DATABASE_URL from environment")
        if wait_for_postgres(database_url):
            return database_url
    
    # Priority 2: Build from individual components
    db_host = os.getenv("DB_HOST", "postgres")  # Use service name by default
    db_port = os.getenv("DB_PORT", "5432")
    db_user = os.getenv("DB_USER", "aml_user")
    db_password = os.getenv("DB_PASSWORD", "aml_password")
    db_name = os.getenv("DB_NAME", "aml_database")
    
    # Try different host configurations
    host_options = [
        db_host,  # Environment variable or default
        "postgres",  # Docker service name
        "aml-postgres",  # Container name
        "host.docker.internal",  # Docker host
        "172.17.0.1",  # Default Docker bridge
    ]
    
    # If running outside Docker, also try localhost
    if not os.path.exists("/.dockerenv"):
        host_options.extend(["localhost", "127.0.0.1"])
        db_port = os.getenv("DB_PORT", "5433")  # Use mapped port for host
    
    for host in host_options:
        database_url = f"postgresql://{db_user}:{db_password}@{host}:{db_port}/{db_name}"
        logger.info(f"Trying PostgreSQL at {host}:{db_port}")
        
        if wait_for_postgres(database_url, max_retries=5):
            logger.info(f"Successfully connected to PostgreSQL at {host}:{db_port}")
            return database_url
    
    # If all attempts fail, use the last URL (will cause proper error)
    logger.error("Could not connect to PostgreSQL with any configuration")
    return f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"

# Get the database URL
DATABASE_URL = get_database_url()
logger.info(f"Final DATABASE_URL configured: {DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else DATABASE_URL}")