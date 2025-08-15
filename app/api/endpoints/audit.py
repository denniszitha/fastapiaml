from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func
from typing import List, Optional
from datetime import datetime, timedelta
from enum import Enum

from app.db.base import get_db
from app.models.audit import AuditLog, AuditAction, AuditCategory
from app.schemas.audit import (
    AuditLogCreate, AuditLogResponse,
    AuditSummary, AuditFilter
)
from app.api.endpoints.auth import get_current_user, require_role
from app.models.user import User, UserRole
from app.core.config import settings

router = APIRouter()

@router.post("/audit/log", response_model=AuditLogResponse)
async def create_audit_log(
    audit_data: AuditLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create an audit log entry
    """
    audit_log = AuditLog(
        user_id=current_user.id,
        username=current_user.username,
        action=audit_data.action,
        category=audit_data.category,
        resource_type=audit_data.resource_type,
        resource_id=audit_data.resource_id,
        description=audit_data.description,
        ip_address=audit_data.ip_address,
        user_agent=audit_data.user_agent,
        metadata=audit_data.metadata,
        created_at=datetime.now()
    )
    
    db.add(audit_log)
    db.commit()
    db.refresh(audit_log)
    
    return audit_log

@router.get("/audit/logs", response_model=List[AuditLogResponse])
async def get_audit_logs(
    skip: int = 0,
    limit: int = Query(100, le=1000),
    user_id: Optional[int] = None,
    action: Optional[AuditAction] = None,
    category: Optional[AuditCategory] = None,
    resource_type: Optional[str] = None,
    resource_id: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    search: Optional[str] = None,
    current_user: User = Depends(require_role([UserRole.ADMIN, UserRole.COMPLIANCE])),
    db: Session = Depends(get_db)
):
    """
    Get audit logs with filtering options
    """
    query = db.query(AuditLog)
    
    # Apply filters
    if user_id:
        query = query.filter(AuditLog.user_id == user_id)
    if action:
        query = query.filter(AuditLog.action == action)
    if category:
        query = query.filter(AuditLog.category == category)
    if resource_type:
        query = query.filter(AuditLog.resource_type == resource_type)
    if resource_id:
        query = query.filter(AuditLog.resource_id == resource_id)
    if start_date:
        query = query.filter(AuditLog.created_at >= start_date)
    if end_date:
        query = query.filter(AuditLog.created_at <= end_date)
    if search:
        query = query.filter(
            or_(
                AuditLog.description.contains(search),
                AuditLog.username.contains(search),
                AuditLog.resource_id.contains(search)
            )
        )
    
    # Order by most recent first
    query = query.order_by(AuditLog.created_at.desc())
    
    return query.offset(skip).limit(limit).all()

@router.get("/audit/logs/{log_id}", response_model=AuditLogResponse)
async def get_audit_log(
    log_id: int,
    current_user: User = Depends(require_role([UserRole.ADMIN, UserRole.COMPLIANCE])),
    db: Session = Depends(get_db)
):
    """
    Get a specific audit log entry
    """
    audit_log = db.query(AuditLog).filter(AuditLog.id == log_id).first()
    
    if not audit_log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audit log not found"
        )
    
    return audit_log

@router.get("/audit/summary", response_model=AuditSummary)
async def get_audit_summary(
    days: int = Query(30, description="Number of days to look back"),
    current_user: User = Depends(require_role([UserRole.ADMIN, UserRole.COMPLIANCE])),
    db: Session = Depends(get_db)
):
    """
    Get audit summary statistics
    """
    start_date = datetime.now() - timedelta(days=days)
    
    # Total logs
    total_logs = db.query(func.count(AuditLog.id)).filter(
        AuditLog.created_at >= start_date
    ).scalar()
    
    # Logs by action
    logs_by_action = db.query(
        AuditLog.action,
        func.count(AuditLog.id).label('count')
    ).filter(
        AuditLog.created_at >= start_date
    ).group_by(AuditLog.action).all()
    
    # Logs by category
    logs_by_category = db.query(
        AuditLog.category,
        func.count(AuditLog.id).label('count')
    ).filter(
        AuditLog.created_at >= start_date
    ).group_by(AuditLog.category).all()
    
    # Most active users
    most_active_users = db.query(
        AuditLog.username,
        func.count(AuditLog.id).label('action_count')
    ).filter(
        AuditLog.created_at >= start_date
    ).group_by(AuditLog.username).order_by(
        func.count(AuditLog.id).desc()
    ).limit(10).all()
    
    # Daily activity
    daily_activity = db.query(
        func.date(AuditLog.created_at).label('date'),
        func.count(AuditLog.id).label('count')
    ).filter(
        AuditLog.created_at >= start_date
    ).group_by('date').all()
    
    return {
        "period": {
            "start": start_date,
            "end": datetime.now(),
            "days": days
        },
        "total_logs": total_logs or 0,
        "logs_by_action": [
            {"action": action.value if action else "Unknown", "count": count}
            for action, count in logs_by_action
        ],
        "logs_by_category": [
            {"category": category.value if category else "Unknown", "count": count}
            for category, count in logs_by_category
        ],
        "most_active_users": [
            {"username": username, "action_count": count}
            for username, count in most_active_users
        ],
        "daily_activity": [
            {"date": str(date), "count": count}
            for date, count in daily_activity
        ]
    }

@router.get("/audit/user/{user_id}", response_model=List[AuditLogResponse])
async def get_user_audit_logs(
    user_id: int,
    skip: int = 0,
    limit: int = Query(100, le=1000),
    current_user: User = Depends(require_role([UserRole.ADMIN, UserRole.COMPLIANCE])),
    db: Session = Depends(get_db)
):
    """
    Get all audit logs for a specific user
    """
    logs = db.query(AuditLog).filter(
        AuditLog.user_id == user_id
    ).order_by(
        AuditLog.created_at.desc()
    ).offset(skip).limit(limit).all()
    
    return logs

@router.get("/audit/resource/{resource_type}/{resource_id}", response_model=List[AuditLogResponse])
async def get_resource_audit_logs(
    resource_type: str,
    resource_id: str,
    skip: int = 0,
    limit: int = Query(100, le=1000),
    current_user: User = Depends(require_role([UserRole.ADMIN, UserRole.COMPLIANCE])),
    db: Session = Depends(get_db)
):
    """
    Get all audit logs for a specific resource
    """
    logs = db.query(AuditLog).filter(
        AuditLog.resource_type == resource_type,
        AuditLog.resource_id == resource_id
    ).order_by(
        AuditLog.created_at.desc()
    ).offset(skip).limit(limit).all()
    
    return logs

@router.post("/audit/export")
async def export_audit_logs(
    filter: AuditFilter,
    format: str = Query("csv", description="Export format: csv, json, excel"),
    current_user: User = Depends(require_role([UserRole.ADMIN, UserRole.COMPLIANCE])),
    db: Session = Depends(get_db)
):
    """
    Export audit logs based on filters
    """
    query = db.query(AuditLog)
    
    # Apply filters from AuditFilter
    if filter.start_date:
        query = query.filter(AuditLog.created_at >= filter.start_date)
    if filter.end_date:
        query = query.filter(AuditLog.created_at <= filter.end_date)
    if filter.user_ids:
        query = query.filter(AuditLog.user_id.in_(filter.user_ids))
    if filter.actions:
        query = query.filter(AuditLog.action.in_(filter.actions))
    if filter.categories:
        query = query.filter(AuditLog.category.in_(filter.categories))
    
    logs = query.all()
    
    # In production, convert logs to requested format and return file
    return {
        "message": f"Exporting {len(logs)} audit logs",
        "format": format,
        "download_url": f"/api/v1/audit/download/audit_logs_{datetime.now().timestamp()}.{format}"
    }

@router.delete("/audit/cleanup")
async def cleanup_old_audit_logs(
    days: int = Query(365, description="Delete logs older than this many days"),
    current_user: User = Depends(require_role([UserRole.ADMIN])),
    db: Session = Depends(get_db)
):
    """
    Clean up old audit logs (admin only)
    """
    cutoff_date = datetime.now() - timedelta(days=days)
    
    # Count logs to be deleted
    count = db.query(func.count(AuditLog.id)).filter(
        AuditLog.created_at < cutoff_date
    ).scalar()
    
    # Delete old logs
    db.query(AuditLog).filter(
        AuditLog.created_at < cutoff_date
    ).delete()
    db.commit()
    
    # Create audit log for this action
    cleanup_log = AuditLog(
        user_id=current_user.id,
        username=current_user.username,
        action=AuditAction.DELETE,
        category=AuditCategory.SYSTEM,
        resource_type="audit_logs",
        resource_id="cleanup",
        description=f"Cleaned up {count} audit logs older than {days} days",
        created_at=datetime.now()
    )
    db.add(cleanup_log)
    db.commit()
    
    return {
        "message": f"Deleted {count} audit logs older than {days} days",
        "cutoff_date": cutoff_date
    }

@router.get("/audit/compliance/report")
async def get_compliance_audit_report(
    start_date: datetime,
    end_date: datetime,
    current_user: User = Depends(require_role([UserRole.ADMIN, UserRole.COMPLIANCE])),
    db: Session = Depends(get_db)
):
    """
    Generate compliance audit report
    """
    # Get all compliance-related actions
    compliance_logs = db.query(AuditLog).filter(
        and_(
            AuditLog.created_at >= start_date,
            AuditLog.created_at <= end_date,
            AuditLog.category == AuditCategory.COMPLIANCE
        )
    ).all()
    
    # Get suspicious transaction reviews
    transaction_reviews = db.query(AuditLog).filter(
        and_(
            AuditLog.created_at >= start_date,
            AuditLog.created_at <= end_date,
            AuditLog.resource_type == "suspicious_case",
            AuditLog.action.in_([AuditAction.VIEW, AuditAction.UPDATE])
        )
    ).count()
    
    # Get report generations
    report_generations = db.query(AuditLog).filter(
        and_(
            AuditLog.created_at >= start_date,
            AuditLog.created_at <= end_date,
            AuditLog.resource_type == "report",
            AuditLog.action == AuditAction.CREATE
        )
    ).count()
    
    # Get user access patterns
    user_access = db.query(
        AuditLog.username,
        func.count(AuditLog.id).label('access_count')
    ).filter(
        and_(
            AuditLog.created_at >= start_date,
            AuditLog.created_at <= end_date,
            AuditLog.action == AuditAction.LOGIN
        )
    ).group_by(AuditLog.username).all()
    
    return {
        "report_period": {
            "start": start_date,
            "end": end_date
        },
        "compliance_actions": len(compliance_logs),
        "transaction_reviews": transaction_reviews,
        "reports_generated": report_generations,
        "user_access_summary": [
            {"username": username, "login_count": count}
            for username, count in user_access
        ],
        "key_activities": [
            {
                "timestamp": log.created_at,
                "user": log.username,
                "action": log.action.value,
                "description": log.description
            }
            for log in compliance_logs[:20]  # Last 20 compliance activities
        ]
    }