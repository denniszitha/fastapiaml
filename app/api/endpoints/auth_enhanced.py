"""
Enhanced authentication endpoints with better error handling and CORS support
"""
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional
import logging

from app.db.base import get_db
from app.models.user import User, AuditTrail
from app.core.security import verify_password, get_password_hash, create_access_token, verify_token
from app.core.config import settings
from pydantic import BaseModel, EmailStr

logger = logging.getLogger(__name__)

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

# Pydantic models
class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    created_at: Optional[datetime]
    
    class Config:
        from_attributes = True

class ErrorResponse(BaseModel):
    detail: str
    error_code: Optional[str] = None

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    """Get current authenticated user with better error handling"""
    try:
        email = verify_token(token)
        if email is None:
            logger.warning(f"Invalid token provided")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        user = db.query(User).filter(User.email == email).first()
        if user is None:
            logger.warning(f"User not found for email: {email}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        return user
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_current_user: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication service error"
        )

@router.post("/auth/login", response_model=Token, responses={
    401: {"model": ErrorResponse, "description": "Invalid credentials"},
    500: {"model": ErrorResponse, "description": "Internal server error"}
})
async def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """
    Login endpoint with enhanced error handling and logging
    """
    try:
        # Log the login attempt
        client_ip = request.client.host if request.client else "unknown"
        logger.info(f"Login attempt from IP: {client_ip} for email: {form_data.username}")
        
        # Find user by email
        user = db.query(User).filter(User.email == form_data.username).first()
        
        if not user:
            logger.warning(f"Login failed: User not found - {form_data.username}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Verify password
        if not verify_password(form_data.password, user.password):
            logger.warning(f"Login failed: Invalid password for user - {form_data.username}")
            
            # Record failed login attempt
            audit = AuditTrail(
                user_id=user.id,
                module="Authentication",
                activity=f"Failed login attempt for: {user.email}",
                ip_address=client_ip
            )
            db.add(audit)
            db.commit()
            
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Create access token
        access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user.email},
            expires_delta=access_token_expires
        )
        
        # Log successful login
        audit = AuditTrail(
            user_id=user.id,
            module="Authentication",
            activity=f"Successful login: {user.email}",
            ip_address=client_ip
        )
        db.add(audit)
        db.commit()
        
        logger.info(f"Successful login for user: {user.email}")
        
        return {
            "access_token": access_token,
            "token_type": "bearer"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication service temporarily unavailable"
        )

@router.post("/auth/register", response_model=UserResponse)
async def register(
    user_data: UserCreate,
    request: Request,
    db: Session = Depends(get_db)
):
    """Register a new user with enhanced error handling"""
    try:
        client_ip = request.client.host if request.client else "unknown"
        
        # Check if user already exists
        existing_user = db.query(User).filter(User.email == user_data.email).first()
        if existing_user:
            logger.warning(f"Registration failed: Email already exists - {user_data.email}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        
        # Create new user
        hashed_password = get_password_hash(user_data.password)
        new_user = User(
            name=user_data.name,
            email=user_data.email,
            password=hashed_password
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        # Log the registration
        audit = AuditTrail(
            user_id=new_user.id,
            module="Authentication",
            activity=f"User registered: {new_user.email}",
            ip_address=client_ip
        )
        db.add(audit)
        db.commit()
        
        logger.info(f"New user registered: {new_user.email}")
        return new_user
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration service temporarily unavailable"
        )

@router.get("/auth/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current user information"""
    return current_user

@router.post("/auth/logout")
async def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Logout the current user"""
    try:
        client_ip = request.client.host if request.client else "unknown"
        
        # Log the logout
        audit = AuditTrail(
            user_id=current_user.id,
            module="Authentication",
            activity=f"User logged out: {current_user.email}",
            ip_address=client_ip
        )
        db.add(audit)
        db.commit()
        
        logger.info(f"User logged out: {current_user.email}")
        return {"message": "Successfully logged out"}
        
    except Exception as e:
        logger.error(f"Logout error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Logout service error"
        )

@router.options("/auth/login")
async def login_options():
    """Handle OPTIONS request for login endpoint"""
    return JSONResponse(
        content={"message": "OK"},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
        }
    )

@router.get("/auth/health")
async def auth_health():
    """Health check endpoint for authentication service"""
    return {"status": "healthy", "service": "authentication"}