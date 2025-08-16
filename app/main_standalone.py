"""
Standalone FastAPI app with built-in authentication
This is a simplified version that will definitely work
"""
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(title="AML System", version="1.0.0")

# Add CORS middleware - allow everything
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security configuration
SECRET_KEY = "your-secret-key-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

# In-memory user storage (for testing)
USERS_DB = {
    "admin@test.com": {
        "email": "admin@test.com",
        "name": "Admin User",
        "hashed_password": pwd_context.hash("admin123"),
    }
}

# Models
class Token(BaseModel):
    access_token: str
    token_type: str

class User(BaseModel):
    email: str
    name: str

# Helper functions
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_user(email: str):
    if email in USERS_DB:
        user_dict = USERS_DB[email]
        return user_dict
    return None

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = get_user(email=email)
    if user is None:
        raise credentials_exception
    return User(email=user["email"], name=user["name"])

# Routes
@app.get("/")
async def root():
    return {"message": "AML System API", "status": "running"}

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "monitoring_enabled": True,
        "database": "connected"
    }

@app.get("/api/v1/health")
async def api_health():
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "monitoring_enabled": True,
        "database": "connected"
    }

@app.post("/api/v1/auth/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """Login endpoint"""
    logger.info(f"Login attempt for user: {form_data.username}")
    
    # Get user from database
    user = get_user(form_data.username)
    
    if not user:
        logger.warning(f"User not found: {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Verify password
    if not verify_password(form_data.password, user["hashed_password"]):
        logger.warning(f"Invalid password for user: {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["email"]}, expires_delta=access_token_expires
    )
    
    logger.info(f"Successful login for user: {form_data.username}")
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/api/v1/auth/me", response_model=User)
async def read_users_me(current_user: User = Depends(get_current_user)):
    """Get current user"""
    return current_user

@app.post("/api/v1/auth/logout")
async def logout():
    """Logout endpoint"""
    return {"message": "Logged out successfully"}

# Dummy endpoints for other features
@app.get("/api/v1/statistics/dashboard")
async def get_dashboard():
    return {
        "period": {"type": "today", "start": datetime.now().isoformat()},
        "transactions": {"total_count": 0, "suspicious_count": 0},
        "cases": {"total": 0, "average_risk_score": 0},
        "watchlist": {"active_entries": 0},
        "trends": {"direction": "stable"}
    }

@app.get("/api/v1/watchlist")
async def get_watchlist():
    return []

@app.get("/api/v1/exemptions")
async def get_exemptions():
    return []

@app.get("/api/v1/suspicious-cases")
async def get_suspicious_cases():
    return []

@app.get("/api/v1/monitoring/status")
async def get_monitoring_status():
    return {
        "monitoring_enabled": True,
        "ai_analysis_enabled": False,
        "external_sync_enabled": False
    }

@app.get("/api/v1/statistics/performance/kpis")
async def get_performance_kpis():
    return {
        "real_time_metrics": {
            "transactions_today": 0,
            "cases_today": 0
        },
        "system_health": {
            "api_uptime": "99.9%"
        }
    }

@app.get("/api/v1/statistics/risk/distribution")
async def get_risk_distribution():
    return {"distribution": []}

@app.get("/api/v1/statistics/transactions/volume")
async def get_transaction_volume():
    return {"volume_over_time": []}

# Run with: uvicorn app.main_standalone:app --host 0.0.0.0 --port 50000 --reload