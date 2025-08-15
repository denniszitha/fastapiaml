from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, case, extract
from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta, date
from decimal import Decimal

from app.db.base import get_db
from app.models.transaction import (
    SuspiciousCase, CustomerProfile, Transaction,
    Watchlist, TransactionExemption, TransactionStatus
)
from app.core.config import settings

router = APIRouter()

@router.get("/statistics/dashboard")
async def get_dashboard_statistics(
    period: str = Query("today", description="Period: today, week, month, year"),
    db: Session = Depends(get_db)
):
    """
    Get dashboard statistics for the specified period
    """
    # Calculate date range
    end_date = datetime.now()
    if period == "today":
        start_date = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == "week":
        start_date = end_date - timedelta(days=7)
    elif period == "month":
        start_date = end_date - timedelta(days=30)
    elif period == "year":
        start_date = end_date - timedelta(days=365)
    else:
        start_date = end_date - timedelta(days=30)
    
    # Transaction statistics
    total_transactions = db.query(func.count(Transaction.id)).filter(
        Transaction.created_at.between(start_date, end_date)
    ).scalar() or 0
    
    total_amount = db.query(func.sum(Transaction.amount)).filter(
        Transaction.created_at.between(start_date, end_date)
    ).scalar() or Decimal(0)
    
    # Suspicious cases statistics
    suspicious_cases = db.query(func.count(SuspiciousCase.id)).filter(
        SuspiciousCase.created_at.between(start_date, end_date)
    ).scalar() or 0
    
    cases_by_status = db.query(
        SuspiciousCase.status,
        func.count(SuspiciousCase.id).label('count')
    ).filter(
        SuspiciousCase.created_at.between(start_date, end_date)
    ).group_by(SuspiciousCase.status).all()
    
    # Risk statistics
    high_risk_cases = db.query(func.count(SuspiciousCase.id)).filter(
        and_(
            SuspiciousCase.created_at.between(start_date, end_date),
            SuspiciousCase.risk_score >= 70
        )
    ).scalar() or 0
    
    avg_risk_score = db.query(func.avg(SuspiciousCase.risk_score)).filter(
        SuspiciousCase.created_at.between(start_date, end_date)
    ).scalar() or 0
    
    # Watchlist statistics
    watchlist_hits = db.query(func.count(SuspiciousCase.id)).filter(
        and_(
            SuspiciousCase.created_at.between(start_date, end_date),
            SuspiciousCase.is_watchlisted == True
        )
    ).scalar() or 0
    
    # Calculate trends (compare with previous period)
    if period == "today":
        prev_start = start_date - timedelta(days=1)
        prev_end = start_date
    else:
        period_duration = end_date - start_date
        prev_start = start_date - period_duration
        prev_end = start_date
    
    prev_suspicious = db.query(func.count(SuspiciousCase.id)).filter(
        SuspiciousCase.created_at.between(prev_start, prev_end)
    ).scalar() or 0
    
    trend = ((suspicious_cases - prev_suspicious) / prev_suspicious * 100) if prev_suspicious > 0 else 0
    
    return {
        "period": {
            "type": period,
            "start": start_date,
            "end": end_date
        },
        "transactions": {
            "total_count": total_transactions,
            "total_amount": float(total_amount),
            "suspicious_count": suspicious_cases,
            "suspicious_percentage": round((suspicious_cases / total_transactions * 100) if total_transactions > 0 else 0, 2)
        },
        "cases": {
            "total": suspicious_cases,
            "by_status": {
                status.value if status else "unknown": count 
                for status, count in cases_by_status
            },
            "high_risk": high_risk_cases,
            "average_risk_score": round(float(avg_risk_score), 2)
        },
        "watchlist": {
            "hits": watchlist_hits,
            "active_entries": db.query(func.count(Watchlist.id)).filter(
                Watchlist.is_active == True
            ).scalar() or 0
        },
        "trends": {
            "suspicious_cases_change": round(trend, 2),
            "direction": "up" if trend > 0 else "down" if trend < 0 else "stable"
        }
    }

@router.get("/statistics/transactions/volume")
async def get_transaction_volume_statistics(
    days: int = Query(30, description="Number of days to analyze"),
    group_by: str = Query("day", description="Group by: day, week, month"),
    db: Session = Depends(get_db)
):
    """
    Get transaction volume statistics over time
    """
    start_date = datetime.now() - timedelta(days=days)
    
    # Determine grouping
    if group_by == "day":
        date_group = func.date(Transaction.created_at)
    elif group_by == "week":
        date_group = func.date_trunc('week', Transaction.created_at)
    elif group_by == "month":
        date_group = func.date_trunc('month', Transaction.created_at)
    else:
        date_group = func.date(Transaction.created_at)
    
    # Get volume data
    volume_data = db.query(
        date_group.label('period'),
        func.count(Transaction.id).label('transaction_count'),
        func.sum(Transaction.amount).label('total_amount'),
        func.avg(Transaction.amount).label('avg_amount')
    ).filter(
        Transaction.created_at >= start_date
    ).group_by('period').order_by('period').all()
    
    # Get channel distribution
    channel_data = db.query(
        Transaction.channel,
        func.count(Transaction.id).label('count'),
        func.sum(Transaction.amount).label('amount')
    ).filter(
        Transaction.created_at >= start_date
    ).group_by(Transaction.channel).all()
    
    return {
        "period": {
            "start": start_date,
            "end": datetime.now(),
            "days": days,
            "grouping": group_by
        },
        "volume_over_time": [
            {
                "period": str(period),
                "transaction_count": count,
                "total_amount": float(total) if total else 0,
                "average_amount": float(avg) if avg else 0
            }
            for period, count, total, avg in volume_data
        ],
        "channel_distribution": [
            {
                "channel": channel or "Unknown",
                "transaction_count": count,
                "total_amount": float(amount) if amount else 0
            }
            for channel, count, amount in channel_data
        ],
        "summary": {
            "total_transactions": sum(d[1] for d in volume_data),
            "total_amount": sum(float(d[2]) if d[2] else 0 for d in volume_data),
            "average_daily_transactions": sum(d[1] for d in volume_data) / days if days > 0 else 0
        }
    }

@router.get("/statistics/risk/distribution")
async def get_risk_distribution(
    db: Session = Depends(get_db)
):
    """
    Get risk score distribution across customer profiles
    """
    # Risk distribution
    risk_distribution = db.query(
        case(
            (CustomerProfile.risk_score < 20, 'Very Low'),
            (CustomerProfile.risk_score < 40, 'Low'),
            (CustomerProfile.risk_score < 60, 'Medium'),
            (CustomerProfile.risk_score < 80, 'High'),
            else_='Critical'
        ).label('risk_level'),
        func.count(CustomerProfile.id).label('count'),
        func.avg(CustomerProfile.total_amount).label('avg_transaction_amount')
    ).group_by('risk_level').all()
    
    # Top risky customers
    top_risky = db.query(CustomerProfile).order_by(
        CustomerProfile.risk_score.desc()
    ).limit(10).all()
    
    # Risk score trends
    risk_trends = db.query(
        func.date(CustomerProfile.last_activity).label('date'),
        func.avg(CustomerProfile.risk_score).label('avg_score')
    ).filter(
        CustomerProfile.last_activity >= datetime.now() - timedelta(days=30)
    ).group_by('date').order_by('date').all()
    
    return {
        "distribution": [
            {
                "risk_level": level,
                "customer_count": count,
                "average_transaction_amount": float(avg_amount) if avg_amount else 0
            }
            for level, count, avg_amount in risk_distribution
        ],
        "high_risk_customers": [
            {
                "account_number": profile.acct_no,
                "account_name": profile.acct_name,
                "risk_score": profile.risk_score,
                "suspicious_count": profile.suspicious_count,
                "total_transactions": profile.total_transactions
            }
            for profile in top_risky
        ],
        "risk_score_trends": [
            {
                "date": str(date),
                "average_risk_score": float(score) if score else 0
            }
            for date, score in risk_trends
        ],
        "summary": {
            "total_profiles": db.query(func.count(CustomerProfile.id)).scalar() or 0,
            "average_risk_score": db.query(func.avg(CustomerProfile.risk_score)).scalar() or 0,
            "high_risk_count": db.query(func.count(CustomerProfile.id)).filter(
                CustomerProfile.risk_score >= 70
            ).scalar() or 0
        }
    }

@router.get("/statistics/compliance/metrics")
async def get_compliance_metrics(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db: Session = Depends(get_db)
):
    """
    Get compliance metrics and KPIs
    """
    if not start_date:
        start_date = datetime.now() - timedelta(days=30)
    if not end_date:
        end_date = datetime.now()
    
    # STR filing metrics
    total_cases = db.query(func.count(SuspiciousCase.id)).filter(
        SuspiciousCase.created_at.between(start_date, end_date)
    ).scalar() or 0
    
    reported_cases = db.query(func.count(SuspiciousCase.id)).filter(
        and_(
            SuspiciousCase.created_at.between(start_date, end_date),
            SuspiciousCase.status == TransactionStatus.REPORTED
        )
    ).scalar() or 0
    
    # Response time metrics
    avg_response_time = db.query(
        func.avg(
            func.extract('epoch', SuspiciousCase.updated_at - SuspiciousCase.created_at) / 3600
        )
    ).filter(
        and_(
            SuspiciousCase.created_at.between(start_date, end_date),
            SuspiciousCase.status != TransactionStatus.PENDING
        )
    ).scalar() or 0
    
    # False positive rate
    false_positives = db.query(func.count(SuspiciousCase.id)).filter(
        and_(
            SuspiciousCase.created_at.between(start_date, end_date),
            SuspiciousCase.status == TransactionStatus.CLOSED
        )
    ).scalar() or 0
    
    # Watchlist effectiveness
    watchlist_detections = db.query(func.count(SuspiciousCase.id)).filter(
        and_(
            SuspiciousCase.created_at.between(start_date, end_date),
            SuspiciousCase.is_watchlisted == True
        )
    ).scalar() or 0
    
    # Exemption usage
    active_exemptions = db.query(func.count(TransactionExemption.id)).filter(
        TransactionExemption.is_active == True
    ).scalar() or 0
    
    return {
        "period": {
            "start": start_date,
            "end": end_date
        },
        "str_metrics": {
            "total_cases": total_cases,
            "reported_cases": reported_cases,
            "reporting_rate": round((reported_cases / total_cases * 100) if total_cases > 0 else 0, 2),
            "average_response_hours": round(float(avg_response_time), 2)
        },
        "quality_metrics": {
            "false_positive_rate": round((false_positives / total_cases * 100) if total_cases > 0 else 0, 2),
            "watchlist_detection_rate": round((watchlist_detections / total_cases * 100) if total_cases > 0 else 0, 2),
            "active_exemptions": active_exemptions
        },
        "efficiency_metrics": {
            "cases_per_day": round(total_cases / ((end_date - start_date).days or 1), 2),
            "average_resolution_time": round(float(avg_response_time), 2),
            "pending_cases": db.query(func.count(SuspiciousCase.id)).filter(
                SuspiciousCase.status == TransactionStatus.PENDING
            ).scalar() or 0
        }
    }

@router.get("/statistics/geographic/distribution")
async def get_geographic_distribution(
    db: Session = Depends(get_db)
):
    """
    Get geographic distribution of transactions and risks
    """
    # Country distribution
    country_stats = db.query(
        CustomerProfile.country,
        func.count(CustomerProfile.id).label('customer_count'),
        func.avg(CustomerProfile.risk_score).label('avg_risk_score'),
        func.sum(CustomerProfile.total_amount).label('total_amount')
    ).group_by(CustomerProfile.country).all()
    
    # Branch distribution
    branch_stats = db.query(
        CustomerProfile.branch,
        func.count(CustomerProfile.id).label('customer_count'),
        func.sum(CustomerProfile.suspicious_count).label('suspicious_count')
    ).group_by(CustomerProfile.branch).all()
    
    return {
        "country_distribution": [
            {
                "country": country or "Unknown",
                "customer_count": count,
                "average_risk_score": float(avg_risk) if avg_risk else 0,
                "total_transaction_amount": float(total) if total else 0
            }
            for country, count, avg_risk, total in country_stats
        ],
        "branch_distribution": [
            {
                "branch": branch or "Unknown",
                "customer_count": count,
                "suspicious_transactions": suspicious or 0
            }
            for branch, count, suspicious in branch_stats
        ],
        "high_risk_regions": [
            {
                "country": country,
                "risk_score": float(avg_risk)
            }
            for country, _, avg_risk, _ in country_stats
            if avg_risk and float(avg_risk) > 60
        ]
    }

@router.get("/statistics/performance/kpis")
async def get_performance_kpis(
    db: Session = Depends(get_db)
):
    """
    Get system performance KPIs
    """
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    this_month_start = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    return {
        "real_time_metrics": {
            "transactions_today": db.query(func.count(Transaction.id)).filter(
                Transaction.created_at >= today
            ).scalar() or 0,
            "cases_today": db.query(func.count(SuspiciousCase.id)).filter(
                SuspiciousCase.created_at >= today
            ).scalar() or 0,
            "active_monitoring": settings.MONITORING_ENABLED
        },
        "monthly_kpis": {
            "transactions_processed": db.query(func.count(Transaction.id)).filter(
                Transaction.created_at >= this_month_start
            ).scalar() or 0,
            "cases_identified": db.query(func.count(SuspiciousCase.id)).filter(
                SuspiciousCase.created_at >= this_month_start
            ).scalar() or 0,
            "strs_filed": db.query(func.count(SuspiciousCase.id)).filter(
                and_(
                    SuspiciousCase.created_at >= this_month_start,
                    SuspiciousCase.status == TransactionStatus.REPORTED
                )
            ).scalar() or 0
        },
        "system_health": {
            "database_size": "125 MB",  # In production, get actual DB size
            "api_uptime": "99.9%",  # In production, calculate from monitoring
            "average_response_time": "245ms",  # In production, get from APM
            "error_rate": "0.1%"  # In production, calculate from logs
        }
    }