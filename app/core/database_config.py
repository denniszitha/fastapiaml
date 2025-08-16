"""
Database configuration with fallback options
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError
import logging

logger = logging.getLogger(__name__)

def get_database_url():
    """
    Get database URL with fallback options for different network configurations
    """
    db_password = os.getenv("DB_PASSWORD", "aml_password")
    
    # Try different connection options
    connection_options = [
        # Docker network using service name
        f"postgresql://aml_user:{db_password}@postgres:5432/aml_database",
        # Docker network using container name
        f"postgresql://aml_user:{db_password}@aml-postgres:5432/aml_database",
        # Host network using localhost and mapped port
        f"postgresql://aml_user:{db_password}@host.docker.internal:5433/aml_database",
        # Direct localhost connection
        f"postgresql://aml_user:{db_password}@localhost:5433/aml_database",
        # IP-based connection
        f"postgresql://aml_user:{db_password}@172.17.0.1:5433/aml_database",
    ]
    
    # Check if DATABASE_URL is explicitly set
    explicit_url = os.getenv("DATABASE_URL")
    if explicit_url:
        connection_options.insert(0, explicit_url)
    
    # Try each connection option
    for url in connection_options:
        try:
            logger.info(f"Trying database connection: {url.split('@')[1].split('/')[0]}")
            engine = create_engine(url, pool_pre_ping=True)
            with engine.connect() as conn:
                conn.execute("SELECT 1")
                logger.info(f"Successfully connected to database")
                return url
        except OperationalError as e:
            logger.warning(f"Failed to connect: {str(e)[:100]}")
            continue
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)[:100]}")
            continue
    
    # Fallback to SQLite for development
    logger.warning("All PostgreSQL connections failed, falling back to SQLite")
    return "sqlite:///./aml_database.db"

# Get the working database URL
DATABASE_URL = get_database_url()