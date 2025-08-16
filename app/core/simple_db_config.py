"""
Simplified database configuration
"""
import os
import logging
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

logger = logging.getLogger(__name__)

def get_database_url():
    """
    Get database URL - simplified approach
    """
    # Check if we should use SQLite (for standalone/simple deployment)
    use_sqlite = os.getenv("USE_SQLITE", "false").lower() == "true"
    if use_sqlite:
        logger.info("Using SQLite database")
        return "sqlite:///./aml_database.db"
    
    # Get database configuration from environment
    db_host = os.getenv("DB_HOST", "localhost")
    db_port = os.getenv("DB_PORT", "5432")
    db_user = os.getenv("DB_USER", "aml_user")
    db_password = os.getenv("DB_PASSWORD", "aml_password")
    db_name = os.getenv("DB_NAME", "aml_database")
    
    # Build PostgreSQL URL
    database_url = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
    
    # Test connection
    try:
        engine = create_engine(database_url, pool_pre_ping=True, connect_args={"connect_timeout": 5})
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            conn.commit()
        logger.info(f"Successfully connected to PostgreSQL at {db_host}:{db_port}")
        return database_url
    except OperationalError as e:
        logger.warning(f"PostgreSQL connection failed: {str(e)[:100]}")
        logger.info("Falling back to SQLite database")
        return "sqlite:///./aml_database.db"
    except Exception as e:
        logger.error(f"Unexpected database error: {str(e)[:100]}")
        logger.info("Falling back to SQLite database")
        return "sqlite:///./aml_database.db"

# Get the database URL
DATABASE_URL = get_database_url()