"""
Database initialization script with proper enum handling
"""
from sqlalchemy import text, inspect
from sqlalchemy.exc import ProgrammingError
from app.db.base import engine, Base, SQLALCHEMY_DATABASE_URL
from app.models import User, CustomerProfile, Watchlist, Exemption, TransactionLimit
import logging

logger = logging.getLogger(__name__)

def check_and_create_enums():
    """Check if enum types exist and create them if needed"""
    # Skip enum creation for SQLite
    if "sqlite" in SQLALCHEMY_DATABASE_URL.lower():
        logger.info("Using SQLite - skipping enum creation")
        return
    
    with engine.connect() as conn:
        # Check existing enum types
        result = conn.execute(text("""
            SELECT typname 
            FROM pg_type 
            WHERE typtype = 'e'
        """))
        existing_enums = {row[0] for row in result}
        
        # Define required enums
        enums_to_create = {
            'transactionstatus': "('pending', 'completed', 'failed', 'cancelled')",
            'riskrating': "('low', 'medium', 'high', 'critical')",
            'casestatus': "('open', 'investigating', 'resolved', 'closed')",
            'limittype': "('daily', 'weekly', 'monthly')"
        }
        
        # Create missing enums
        for enum_name, enum_values in enums_to_create.items():
            if enum_name not in existing_enums:
                try:
                    conn.execute(text(f"CREATE TYPE {enum_name} AS ENUM {enum_values}"))
                    conn.commit()
                    logger.info(f"Created enum type: {enum_name}")
                except ProgrammingError as e:
                    logger.warning(f"Enum {enum_name} might already exist: {e}")
                    conn.rollback()

def init_db():
    """Initialize database with proper error handling"""
    try:
        # First check and create enum types if needed
        check_and_create_enums()
        
        # Then create all tables
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created successfully")
        
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
        # Try alternative approach - drop and recreate
        try:
            logger.info("Attempting to reset database schema...")
            with engine.connect() as conn:
                # Drop all tables
                inspector = inspect(engine)
                for table_name in inspector.get_table_names():
                    conn.execute(text(f"DROP TABLE IF EXISTS {table_name} CASCADE"))
                conn.commit()
                
            # Recreate enums and tables
            check_and_create_enums()
            Base.metadata.create_all(bind=engine)
            logger.info("Database schema reset successfully")
            
        except Exception as reset_error:
            logger.error(f"Failed to reset database: {reset_error}")
            raise

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    init_db()