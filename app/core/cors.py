"""
CORS Configuration Module
Handles Cross-Origin Resource Sharing settings for different environments
"""
from typing import List
import os
from app.core.config import settings

def get_cors_origins() -> List[str]:
    """
    Get CORS allowed origins based on environment
    Returns a list of allowed origins
    """
    # Default development origins
    dev_origins = [
        "http://localhost:3000",
        "http://localhost:3001",
        "http://localhost:3002",
        "http://localhost:3003",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:3001",
        "http://127.0.0.1:3002",
        "http://127.0.0.1:3003",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ]
    
    # Production origins from environment variable
    prod_origins = []
    
    # Get CORS origins from environment variable
    cors_env = os.getenv('CORS_ALLOWED_ORIGINS', '')
    if cors_env:
        # Parse comma-separated origins
        prod_origins = [origin.strip() for origin in cors_env.split(',') if origin.strip()]
    
    # Additional allowed origins from settings
    if hasattr(settings, 'CORS_ORIGINS'):
        additional_origins = settings.CORS_ORIGINS
        if isinstance(additional_origins, str):
            prod_origins.extend([o.strip() for o in additional_origins.split(',') if o.strip()])
        elif isinstance(additional_origins, list):
            prod_origins.extend(additional_origins)
    
    # Combine all origins
    all_origins = list(set(dev_origins + prod_origins))
    
    # In production, you might want to be more restrictive
    # Uncomment the following to only use production origins if specified
    # if prod_origins and os.getenv('ENVIRONMENT') == 'production':
    #     return prod_origins
    
    return all_origins

def get_cors_config():
    """
    Get complete CORS configuration
    """
    return {
        "allow_origins": get_cors_origins(),
        "allow_credentials": True,
        "allow_methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH", "HEAD"],
        "allow_headers": [
            "Accept",
            "Accept-Language",
            "Content-Type",
            "Authorization",
            "X-Requested-With",
            "X-CSRF-Token",
            "X-Request-ID",
            "Cache-Control",
            "Pragma",
        ],
        "expose_headers": [
            "Content-Disposition",
            "Content-Length",
            "X-Request-ID",
        ],
        "max_age": 3600,  # Cache preflight requests for 1 hour
    }