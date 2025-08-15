from fastapi import FastAPI
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

# Set up CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:3001", 
        "http://localhost:3002",
        "http://localhost:3003",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:3001",
        "http://127.0.0.1:3002", 
        "http://127.0.0.1:3003"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
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
    tags=["statistics"]
)

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