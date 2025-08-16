"""
Models package initialization
"""
from app.models.user import User
from app.models.transaction import (
    Transaction, 
    SuspiciousCase,
    CustomerProfile,
    Watchlist,
    TransactionExemption,
    TransactionLimit,
    RawTransaction
)

# Create aliases for compatibility
customer_profile = CustomerProfile
watchlist = Watchlist
exemption = TransactionExemption
Exemption = TransactionExemption  # Alias
transaction_limit = TransactionLimit
suspicious_case = SuspiciousCase

__all__ = [
    'User',
    'Transaction',
    'CustomerProfile',
    'Watchlist',
    'TransactionExemption',
    'Exemption',
    'TransactionLimit',
    'SuspiciousCase',
    'RawTransaction',
    'customer_profile',
    'watchlist',
    'exemption',
    'transaction_limit',
    'suspicious_case'
]