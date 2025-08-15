from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    # Application settings
    APP_NAME: str = "AML Transaction Monitoring System"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    
    # Database settings
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql://user:password@localhost/aml_db"
    )
    
    # API settings
    API_V1_PREFIX: str = "/api/v1"
    API_PORT: int = int(os.getenv("API_PORT", "50000"))
    
    # Security
    WEBHOOK_TOKEN: str = os.getenv("WEBHOOK_TOKEN", "your-secure-webhook-token")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # External API settings
    EXTERNAL_API_URL: str = os.getenv("EXTERNAL_API_URL", "http://10.139.14.99:8000/process_json")
    
    # Feature flags
    MONITORING_ENABLED: bool = True
    ENABLE_AI_ANALYSIS: bool = os.getenv("ENABLE_AI_ANALYSIS", "false").lower() == "true"
    ENABLE_EXTERNAL_SYNC: bool = os.getenv("ENABLE_EXTERNAL_SYNC", "false").lower() == "true"
    
    # CORS settings - Allow all origins for development
    BACKEND_CORS_ORIGINS: list = ["*"]
    
    # Organization
    ORGANIZATION_NAME: str = os.getenv("ORGANIZATION_NAME", "NATSAVE Bank")
    
    # Logging
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "allow"  # Allow extra fields from .env

settings = Settings()