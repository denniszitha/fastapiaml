"""
Models package initialization
"""
from app.models.user import User
from app.models.transaction import Transaction
from app.models.reference import (
    CustomerProfile,
    Watchlist,
    Exemption,
    TransactionLimit
)

# Create aliases for compatibility
customer_profile = CustomerProfile
watchlist = Watchlist
exemption = Exemption
transaction_limit = TransactionLimit

# For backward compatibility - create a mock SuspiciousCase if needed
class SuspiciousCase:
    """Mock SuspiciousCase model for compatibility"""
    pass

suspicious_case = SuspiciousCase

__all__ = [
    'User',
    'Transaction',
    'CustomerProfile',
    'Watchlist',
    'Exemption',
    'TransactionLimit',
    'SuspiciousCase',
    'customer_profile',
    'watchlist',
    'exemption',
    'transaction_limit',
    'suspicious_case'
]