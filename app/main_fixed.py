from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
import logging
import os

from app.core.config import settings
from app.api.endpoints import transaction_monitoring, simple_statistics, auth
from app.db.base import engine, Base
from app.middleware.cors_middleware import cors_middleware

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting up AML Transaction Monitoring System...")
    # Create database tables
    Base.metadata.create_all(bind=engine)
    yield
    # Shutdown
    logger.info("Shutting down...")

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
    lifespan=lifespan
)

# CRITICAL: Add custom CORS middleware FIRST (before CORSMiddleware)
@app.middleware("http")
async def add_cors_headers(request: Request, call_next):
    return await cors_middleware(request, call_next)

# Get allowed origins from environment or use wildcard for simplicity
allowed_origins = os.getenv('CORS_ALLOWED_ORIGINS', '*').split(',')
if '*' in allowed_origins:
    allowed_origins = ["*"]

# Add standard CORS middleware as backup
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=86400,
)

# Add trusted host middleware for production
if os.getenv('ENVIRONMENT') == 'production':
    trusted_hosts = os.getenv('TRUSTED_HOSTS', '').split(',')
    if trusted_hosts and trusted_hosts[0]:
        app.add_middleware(
            TrustedHostMiddleware,
            allowed_hosts=trusted_hosts
        )

# Include routers
app.include_router(
    transaction_monitoring.router,
    prefix=settings.API_V1_PREFIX,
    tags=["transaction-monitoring"]
)

app.include_router(
    simple_statistics.router,
    prefix=settings.API_V1_PREFIX,
    tags=["simple-statistics"]
)

# Check if statistics module exists
try:
    from app.api.endpoints import statistics
    app.include_router(
        statistics.router,
        prefix=settings.API_V1_PREFIX,
        tags=["statistics"]
    )
except ImportError:
    logger.warning("Statistics module not found, skipping...")

app.include_router(
    auth.router,
    prefix=settings.API_V1_PREFIX,
    tags=["authentication"]
)

@app.get("/")
async def root():
    return {
        "message": "AML Transaction Monitoring System",
        "version": settings.APP_VERSION,
        "monitoring_enabled": settings.MONITORING_ENABLED
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "monitoring_enabled": settings.MONITORING_ENABLED,
        "database": "connected",
        "cors_enabled": True
    }

@app.get(f"{settings.API_V1_PREFIX}/health")
async def api_health_check():
    return {
        "status": "healthy",
        "monitoring_enabled": settings.MONITORING_ENABLED,
        "database": "connected",
        "cors_enabled": True
    }

# Add explicit OPTIONS handler for all routes
@app.options("/{full_path:path}")
async def options_handler(full_path: str):
    return {"message": "OK"}