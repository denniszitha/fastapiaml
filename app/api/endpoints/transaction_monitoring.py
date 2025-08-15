from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta
import logging

from app.db.base import get_db
from app.schemas.transaction import (
    TransactionRequest, TransactionResponse, 
    WatchlistCreate, WatchlistResponse,
    TransactionExemptionCreate, TransactionExemptionResponse,
    TransactionLimitCreate, TransactionLimitResponse,
    CustomerProfileResponse, SuspiciousCaseResponse
)
from app.models.transaction import (
    Watchlist, TransactionExemption, TransactionLimit,
    CustomerProfile, SuspiciousCase, TransactionStatus
)
from app.services.transaction_processing import TransactionProcessingService
from app.core.config import settings
from app.core.security import verify_webhook_token

logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/webhook/suspicious", response_model=TransactionResponse)
async def process_suspicious_transaction(
    request: TransactionRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Process incoming suspicious transaction from webhook
    """
    # Verify webhook token
    if not verify_webhook_token(request.perm):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid webhook token"
        )
    
    logger.info(f"Processing transaction for account: {request.current_transaction.acct_no}")
    
    # Initialize processing service
    processing_service = TransactionProcessingService(db)
    
    # Process transaction
    result = processing_service.process_transaction(
        request.current_transaction.model_dump(),
        request.case_number
    )
    
    if not result['success']:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result.get('error', 'Transaction processing failed')
        )
    
    return TransactionResponse(
        success=True,
        message="Transaction processed successfully",
        case_number=result.get('case_number'),
        risk_profile=result.get('risk_profile'),
        is_suspicious=result.get('is_suspicious'),
        flagging_reason=result.get('flagging_reason'),
        customer_profile_id=result.get('customer_profile_id')
    )

@router.post("/watchlist", response_model=WatchlistResponse)
async def add_to_watchlist(
    watchlist_data: WatchlistCreate,
    db: Session = Depends(get_db)
):
    """
    Add an account to the watchlist
    """
    # Check if already exists
    existing = db.query(Watchlist).filter(
        Watchlist.account_number == watchlist_data.account_number
    ).first()
    
    if existing:
        # Update existing entry
        for key, value in watchlist_data.model_dump(exclude_unset=True).items():
            setattr(existing, key, value)
        existing.is_active = True
        db.commit()
        db.refresh(existing)
        return existing
    
    # Create new entry
    watchlist = Watchlist(**watchlist_data.model_dump())
    db.add(watchlist)
    db.commit()
    db.refresh(watchlist)
    return watchlist

@router.get("/watchlist", response_model=List[WatchlistResponse])
async def get_watchlist(
    skip: int = 0,
    limit: int = 100,
    is_active: Optional[bool] = True,
    db: Session = Depends(get_db)
):
    """
    Get all watchlist entries
    """
    query = db.query(Watchlist)
    if is_active is not None:
        query = query.filter(Watchlist.is_active == is_active)
    
    return query.offset(skip).limit(limit).all()

@router.delete("/watchlist/{account_number}")
async def remove_from_watchlist(
    account_number: str,
    db: Session = Depends(get_db)
):
    """
    Remove an account from watchlist (soft delete)
    """
    watchlist = db.query(Watchlist).filter(
        Watchlist.account_number == account_number
    ).first()
    
    if not watchlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found in watchlist"
        )
    
    watchlist.is_active = False
    db.commit()
    
    return {"message": f"Account {account_number} removed from watchlist"}

@router.post("/exemptions", response_model=TransactionExemptionResponse)
async def add_exemption(
    exemption_data: TransactionExemptionCreate,
    db: Session = Depends(get_db)
):
    """
    Add an account to transaction exemptions
    """
    # Check if already exists
    existing = db.query(TransactionExemption).filter(
        TransactionExemption.account_number == exemption_data.account_number
    ).first()
    
    if existing:
        # Update existing entry
        for key, value in exemption_data.model_dump(exclude_unset=True).items():
            setattr(existing, key, value)
        existing.is_active = True
        db.commit()
        db.refresh(existing)
        return existing
    
    # Create new entry
    exemption = TransactionExemption(**exemption_data.model_dump())
    db.add(exemption)
    db.commit()
    db.refresh(exemption)
    return exemption

@router.get("/exemptions", response_model=List[TransactionExemptionResponse])
async def get_exemptions(
    skip: int = 0,
    limit: int = 100,
    is_active: Optional[bool] = True,
    db: Session = Depends(get_db)
):
    """
    Get all transaction exemptions
    """
    query = db.query(TransactionExemption)
    if is_active is not None:
        query = query.filter(TransactionExemption.is_active == is_active)
    
    return query.offset(skip).limit(limit).all()

@router.delete("/exemptions/{account_number}")
async def remove_exemption(
    account_number: str,
    db: Session = Depends(get_db)
):
    """
    Remove an account from exemptions (soft delete)
    """
    exemption = db.query(TransactionExemption).filter(
        TransactionExemption.account_number == account_number
    ).first()
    
    if not exemption:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found in exemptions"
        )
    
    exemption.is_active = False
    db.commit()
    
    return {"message": f"Account {account_number} exemption removed"}

@router.post("/limits", response_model=TransactionLimitResponse)
async def create_transaction_limit(
    limit_data: TransactionLimitCreate,
    db: Session = Depends(get_db)
):
    """
    Create or update a transaction limit
    """
    # Check if limit exists for channel and type
    existing = db.query(TransactionLimit).filter(
        TransactionLimit.channel == limit_data.channel,
        TransactionLimit.type == limit_data.type
    ).first()
    
    if existing:
        # Update existing limit
        for key, value in limit_data.model_dump(exclude_unset=True).items():
            setattr(existing, key, value)
        existing.is_active = True
        db.commit()
        db.refresh(existing)
        return existing
    
    # Create new limit
    limit = TransactionLimit(**limit_data.model_dump())
    db.add(limit)
    db.commit()
    db.refresh(limit)
    return limit

@router.get("/limits", response_model=List[TransactionLimitResponse])
async def get_transaction_limits(
    channel: Optional[str] = None,
    type: Optional[str] = None,
    is_active: Optional[bool] = True,
    db: Session = Depends(get_db)
):
    """
    Get transaction limits
    """
    query = db.query(TransactionLimit)
    
    if channel:
        query = query.filter(TransactionLimit.channel == channel)
    if type:
        query = query.filter(TransactionLimit.type == type)
    if is_active is not None:
        query = query.filter(TransactionLimit.is_active == is_active)
    
    return query.all()

@router.get("/profiles/{account_number}", response_model=CustomerProfileResponse)
async def get_customer_profile(
    account_number: str,
    db: Session = Depends(get_db)
):
    """
    Get customer profile by account number
    """
    profile = db.query(CustomerProfile).filter(
        CustomerProfile.acct_no == account_number
    ).first()
    
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer profile not found"
        )
    
    return profile

@router.get("/suspicious-cases", response_model=List[SuspiciousCaseResponse])
async def get_suspicious_cases(
    skip: int = 0,
    limit: int = 100,
    account_number: Optional[str] = None,
    status: Optional[TransactionStatus] = None,
    from_date: Optional[datetime] = None,
    to_date: Optional[datetime] = None,
    db: Session = Depends(get_db)
):
    """
    Get suspicious cases with optional filters
    """
    query = db.query(SuspiciousCase)
    
    if account_number:
        query = query.filter(SuspiciousCase.account_number == account_number)
    if status:
        query = query.filter(SuspiciousCase.status == status)
    if from_date:
        query = query.filter(SuspiciousCase.transaction_date >= from_date)
    if to_date:
        query = query.filter(SuspiciousCase.transaction_date <= to_date)
    
    return query.order_by(SuspiciousCase.created_at.desc()).offset(skip).limit(limit).all()

@router.get("/suspicious-cases/{case_number}", response_model=SuspiciousCaseResponse)
async def get_suspicious_case(
    case_number: str,
    db: Session = Depends(get_db)
):
    """
    Get a specific suspicious case by case number
    """
    case = db.query(SuspiciousCase).filter(
        SuspiciousCase.case_number == case_number
    ).first()
    
    if not case:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Suspicious case not found"
        )
    
    return case

@router.patch("/suspicious-cases/{case_number}/status")
async def update_case_status(
    case_number: str,
    status: TransactionStatus,
    db: Session = Depends(get_db)
):
    """
    Update the status of a suspicious case
    """
    case = db.query(SuspiciousCase).filter(
        SuspiciousCase.case_number == case_number
    ).first()
    
    if not case:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Suspicious case not found"
        )
    
    case.status = status
    db.commit()
    
    return {"message": f"Case {case_number} status updated to {status.value}"}

@router.get("/monitoring/status")
async def get_monitoring_status():
    """
    Get current monitoring system status
    """
    return {
        "monitoring_enabled": settings.MONITORING_ENABLED,
        "ai_analysis_enabled": settings.ENABLE_AI_ANALYSIS,
        "external_sync_enabled": settings.ENABLE_EXTERNAL_SYNC,
        "webhook_endpoint": "/api/v1/webhook/suspicious"
    }

@router.post("/monitoring/toggle")
async def toggle_monitoring(enable: bool):
    """
    Enable or disable transaction monitoring
    Note: In production, this should update a persistent configuration
    """
    settings.MONITORING_ENABLED = enable
    return {
        "monitoring_enabled": settings.MONITORING_ENABLED,
        "message": f"Transaction monitoring {'enabled' if enable else 'disabled'}"
    }