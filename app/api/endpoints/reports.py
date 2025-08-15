from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta, date
from io import BytesIO
import json

from app.db.base import get_db
from app.models.transaction import (
    SuspiciousCase, CustomerProfile, Transaction,
    Watchlist, TransactionExemption, TransactionStatus
)
from app.schemas.reports import (
    ReportRequest, ReportResponse, ReportType,
    STRReport, ComplianceReport, RiskReport,
    ActivitySummary, ReportFormat
)
from app.core.config import settings
from app.services.report_generator import ReportGeneratorService

router = APIRouter()

@router.post("/reports/generate", response_model=ReportResponse)
async def generate_report(
    request: ReportRequest,
    db: Session = Depends(get_db)
):
    """
    Generate a compliance report based on type and parameters
    """
    report_service = ReportGeneratorService(db)
    
    try:
        if request.report_type == ReportType.STR:
            report_data = report_service.generate_str_report(
                request.case_numbers,
                request.start_date,
                request.end_date
            )
        elif request.report_type == ReportType.COMPLIANCE:
            report_data = report_service.generate_compliance_report(
                request.start_date,
                request.end_date
            )
        elif request.report_type == ReportType.RISK:
            report_data = report_service.generate_risk_report(
                request.start_date,
                request.end_date,
                request.risk_threshold
            )
        elif request.report_type == ReportType.ACTIVITY:
            report_data = report_service.generate_activity_report(
                request.start_date,
                request.end_date
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid report type"
            )
        
        return ReportResponse(
            report_id=report_data.get('report_id'),
            report_type=request.report_type,
            generated_at=datetime.now(),
            file_url=report_data.get('file_url'),
            data=report_data.get('data')
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Report generation failed: {str(e)}"
        )

@router.get("/reports/str/{case_number}")
async def get_str_report(
    case_number: str,
    db: Session = Depends(get_db)
):
    """
    Get Suspicious Transaction Report for a specific case
    """
    case = db.query(SuspiciousCase).filter(
        SuspiciousCase.case_number == case_number
    ).first()
    
    if not case:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found"
        )
    
    # Get customer profile
    profile = db.query(CustomerProfile).filter(
        CustomerProfile.acct_no == case.account_number
    ).first()
    
    return {
        "case_number": case.case_number,
        "filing_date": datetime.now(),
        "reporting_entity": settings.ORGANIZATION_NAME,
        "subject_information": {
            "account_number": case.account_number,
            "account_name": case.account_name,
            "customer_id": profile.id if profile else None,
            "risk_score": case.risk_score
        },
        "transaction_details": {
            "transaction_id": case.transaction_id,
            "amount": case.amount,
            "currency": case.currency,
            "date": case.transaction_date,
            "channel": case.channel
        },
        "suspicious_activity": {
            "category": case.compliance_category,
            "description": case.flagging_reason,
            "risk_indicators": json.loads(case.risk_indicators) if case.risk_indicators else []
        },
        "action_taken": case.status,
        "law_enforcement_contacted": False,
        "narrative": f"Suspicious transaction detected for account {case.account_number}. {case.flagging_reason}"
    }

@router.get("/reports/compliance/monthly")
async def get_monthly_compliance_report(
    year: int = Query(..., description="Year"),
    month: int = Query(..., ge=1, le=12, description="Month"),
    db: Session = Depends(get_db)
):
    """
    Get monthly compliance report with statistics
    """
    start_date = datetime(year, month, 1)
    if month == 12:
        end_date = datetime(year + 1, 1, 1) - timedelta(seconds=1)
    else:
        end_date = datetime(year, month + 1, 1) - timedelta(seconds=1)
    
    # Get statistics
    total_transactions = db.query(func.count(Transaction.id)).filter(
        and_(
            Transaction.created_at >= start_date,
            Transaction.created_at <= end_date
        )
    ).scalar()
    
    suspicious_cases = db.query(func.count(SuspiciousCase.id)).filter(
        and_(
            SuspiciousCase.created_at >= start_date,
            SuspiciousCase.created_at <= end_date
        )
    ).scalar()
    
    high_risk_cases = db.query(func.count(SuspiciousCase.id)).filter(
        and_(
            SuspiciousCase.created_at >= start_date,
            SuspiciousCase.created_at <= end_date,
            SuspiciousCase.risk_score >= 70
        )
    ).scalar()
    
    # STRs filed
    strs_filed = db.query(func.count(SuspiciousCase.id)).filter(
        and_(
            SuspiciousCase.created_at >= start_date,
            SuspiciousCase.created_at <= end_date,
            SuspiciousCase.status == TransactionStatus.REPORTED
        )
    ).scalar()
    
    # Get top risk categories
    risk_categories = db.query(
        SuspiciousCase.compliance_category,
        func.count(SuspiciousCase.id).label('count')
    ).filter(
        and_(
            SuspiciousCase.created_at >= start_date,
            SuspiciousCase.created_at <= end_date
        )
    ).group_by(SuspiciousCase.compliance_category).all()
    
    return {
        "report_period": f"{year}-{month:02d}",
        "generated_at": datetime.now(),
        "summary": {
            "total_transactions_monitored": total_transactions or 0,
            "suspicious_cases_identified": suspicious_cases or 0,
            "high_risk_cases": high_risk_cases or 0,
            "strs_filed": strs_filed or 0,
            "compliance_rate": round((1 - (suspicious_cases / total_transactions if total_transactions else 0)) * 100, 2)
        },
        "risk_categories": [
            {"category": cat, "count": count}
            for cat, count in risk_categories
        ],
        "watchlist_stats": {
            "total_watchlisted": db.query(func.count(Watchlist.id)).filter(
                Watchlist.is_active == True
            ).scalar() or 0,
            "added_this_month": db.query(func.count(Watchlist.id)).filter(
                and_(
                    Watchlist.created_at >= start_date,
                    Watchlist.created_at <= end_date
                )
            ).scalar() or 0
        },
        "exemptions_stats": {
            "active_exemptions": db.query(func.count(TransactionExemption.id)).filter(
                TransactionExemption.is_active == True
            ).scalar() or 0
        }
    }

@router.get("/reports/risk/assessment")
async def get_risk_assessment_report(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    risk_threshold: int = 50,
    db: Session = Depends(get_db)
):
    """
    Generate risk assessment report for customer profiles
    """
    query = db.query(CustomerProfile)
    
    if start_date:
        query = query.filter(CustomerProfile.last_activity >= start_date)
    if end_date:
        query = query.filter(CustomerProfile.last_activity <= end_date)
    
    # Get risk distribution
    risk_distribution = db.query(
        func.case(
            (CustomerProfile.risk_score < 30, 'Low'),
            (CustomerProfile.risk_score < 60, 'Medium'),
            (CustomerProfile.risk_score < 80, 'High'),
            else_='Critical'
        ).label('risk_level'),
        func.count(CustomerProfile.id).label('count')
    ).group_by('risk_level').all()
    
    # Get high risk profiles
    high_risk_profiles = query.filter(
        CustomerProfile.risk_score >= risk_threshold
    ).limit(20).all()
    
    return {
        "report_date": datetime.now(),
        "assessment_period": {
            "start": start_date,
            "end": end_date
        },
        "risk_distribution": [
            {"level": level, "count": count}
            for level, count in risk_distribution
        ],
        "high_risk_profiles": [
            {
                "account_number": p.acct_no,
                "account_name": p.acct_name,
                "risk_score": p.risk_score,
                "total_transactions": p.total_transactions,
                "suspicious_count": p.suspicious_count,
                "last_activity": p.last_activity
            }
            for p in high_risk_profiles
        ],
        "statistics": {
            "total_profiles": db.query(func.count(CustomerProfile.id)).scalar(),
            "average_risk_score": db.query(func.avg(CustomerProfile.risk_score)).scalar() or 0,
            "profiles_above_threshold": query.filter(
                CustomerProfile.risk_score >= risk_threshold
            ).count()
        }
    }

@router.get("/reports/activity/summary")
async def get_activity_summary(
    days: int = Query(30, description="Number of days to look back"),
    db: Session = Depends(get_db)
):
    """
    Get activity summary for the specified period
    """
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    
    # Daily transaction counts
    daily_stats = db.query(
        func.date(SuspiciousCase.created_at).label('date'),
        func.count(SuspiciousCase.id).label('count')
    ).filter(
        SuspiciousCase.created_at >= start_date
    ).group_by('date').all()
    
    # Channel distribution
    channel_stats = db.query(
        SuspiciousCase.channel,
        func.count(SuspiciousCase.id).label('count'),
        func.sum(SuspiciousCase.amount).label('total_amount')
    ).filter(
        SuspiciousCase.created_at >= start_date
    ).group_by(SuspiciousCase.channel).all()
    
    # Status distribution
    status_stats = db.query(
        SuspiciousCase.status,
        func.count(SuspiciousCase.id).label('count')
    ).filter(
        SuspiciousCase.created_at >= start_date
    ).group_by(SuspiciousCase.status).all()
    
    return {
        "period": {
            "start": start_date,
            "end": end_date,
            "days": days
        },
        "daily_activity": [
            {"date": str(date), "suspicious_cases": count}
            for date, count in daily_stats
        ],
        "channel_distribution": [
            {
                "channel": channel,
                "transaction_count": count,
                "total_amount": float(amount) if amount else 0
            }
            for channel, count, amount in channel_stats
        ],
        "status_distribution": [
            {"status": status.value if status else "Unknown", "count": count}
            for status, count in status_stats
        ],
        "summary": {
            "total_cases": sum(count for _, count in status_stats),
            "average_daily": sum(count for _, count in daily_stats) / days if daily_stats else 0,
            "most_active_channel": max(channel_stats, key=lambda x: x[1])[0] if channel_stats else None
        }
    }

@router.post("/reports/export/{report_id}")
async def export_report(
    report_id: str,
    format: ReportFormat = ReportFormat.PDF,
    db: Session = Depends(get_db)
):
    """
    Export a report in specified format
    """
    # In production, this would fetch the actual report data
    # and convert it to the requested format
    
    return {
        "report_id": report_id,
        "format": format,
        "download_url": f"/api/v1/reports/download/{report_id}.{format.value}",
        "expires_at": datetime.now() + timedelta(hours=24)
    }

@router.get("/reports/scheduled")
async def get_scheduled_reports(
    db: Session = Depends(get_db)
):
    """
    Get list of scheduled reports
    """
    # In production, this would fetch from a scheduled_reports table
    return {
        "scheduled_reports": [
            {
                "id": "1",
                "name": "Weekly Compliance Summary",
                "type": "compliance",
                "schedule": "0 9 * * MON",
                "recipients": ["compliance@example.com"],
                "last_run": datetime.now() - timedelta(days=7),
                "next_run": datetime.now() + timedelta(days=7)
            },
            {
                "id": "2",
                "name": "Monthly Risk Assessment",
                "type": "risk",
                "schedule": "0 9 1 * *",
                "recipients": ["risk@example.com"],
                "last_run": datetime.now() - timedelta(days=30),
                "next_run": datetime.now() + timedelta(days=30)
            }
        ]
    }

@router.post("/reports/schedule")
async def schedule_report(
    name: str,
    report_type: ReportType,
    schedule: str,  # Cron expression
    recipients: List[str],
    parameters: Optional[Dict[str, Any]] = None,
    db: Session = Depends(get_db)
):
    """
    Schedule a recurring report
    """
    # In production, this would save to database and set up cron job
    return {
        "message": "Report scheduled successfully",
        "schedule_id": f"SCH-{datetime.now().timestamp()}",
        "name": name,
        "type": report_type,
        "schedule": schedule,
        "recipients": recipients
    }