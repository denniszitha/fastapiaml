from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from app.core.config import settings
from app.api.endpoints import transaction_monitoring, simple_statistics, auth
from app.db.base import engine, Base

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
    try:
        # Import init_db function
        from app.db.init_db import init_db
        # Initialize database with proper enum handling
        init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization error: {e}")
        # Continue anyway - some endpoints might still work
    yield
    # Shutdown
    logger.info("Shutting down...")

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
    lifespan=lifespan
)

# SUPER SIMPLE CORS - Allow everything
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
    expose_headers=["*"],  # Expose all headers
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

# Try to include statistics if it exists
try:
    from app.api.endpoints import statistics
    app.include_router(
        statistics.router,
        prefix=settings.API_V1_PREFIX,
        tags=["statistics"]
    )
except ImportError:
    pass

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
        "database": "connected"
    }

@app.get(f"{settings.API_V1_PREFIX}/health")
async def api_health_check():
    return {
        "status": "healthy",
        "monitoring_enabled": settings.MONITORING_ENABLED,
        "database": "connected"
    }