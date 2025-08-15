from sqlalchemy import Column, String, Float, DateTime, Integer, Text, JSON, Boolean, Enum as SQLEnum
from sqlalchemy.sql import func
from app.db.base import Base
from datetime import datetime
import enum

class RiskLevel(str, enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class TransactionStatus(str, enum.Enum):
    SUSPICIOUS = "suspicious"
    NOT_COMPLIANT = "not compliant"
    COMPLIANT = "compliant"
    PENDING = "pending"
    REVIEWED = "reviewed"

class SuspiciousCase(Base):
    __tablename__ = "suspicious_cases"
    
    id = Column(Integer, primary_key=True, index=True)
    case_number = Column(String(24), unique=True, index=True, nullable=False)
    account_number = Column(String(50), index=True, nullable=False)
    account_name = Column(String(255), nullable=False)
    account_open_date = Column(DateTime)
    transaction_date = Column(DateTime, nullable=False)
    branch_code = Column(String(50))
    address = Column(Text)
    phone = Column(String(50))
    identifier = Column(String(100))
    transaction_id = Column(String(100), unique=True, index=True)
    currency = Column(String(10))
    transaction_type = Column(String(20))
    amount = Column(Float, nullable=False)
    reference = Column(Text)
    tpin_number = Column(String(50))
    status = Column(SQLEnum(TransactionStatus), default=TransactionStatus.SUSPICIOUS)
    flagging_reason = Column(Text)
    sanction_category = Column(String(100))
    sanction_data = Column(JSON)
    watchlist_category = Column(String(100))
    watchlist_data = Column(Text)
    compliance_category = Column(String(100))
    compliance_data = Column(Text)
    photo = Column(Text)
    cif_id = Column(String(50))
    corporateid = Column(String(50))
    entry_date = Column(DateTime)
    value_date = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class Transaction(Base):
    __tablename__ = "transactions"
    
    id = Column(Integer, primary_key=True, index=True)
    case_number = Column(String(24), index=True, nullable=False)
    account_number = Column(String(50), index=True, nullable=False)
    account_name = Column(String(255), nullable=False)
    account_open_date = Column(DateTime)
    transaction_date = Column(DateTime, nullable=False)
    branch_code = Column(String(50))
    address = Column(Text)
    phone = Column(String(50))
    identifier = Column(String(100))
    transaction_id = Column(String(100), unique=True, index=True)
    currency = Column(String(10))
    transaction_type = Column(String(20))
    amount = Column(Float, nullable=False)
    reference = Column(Text)
    tpin_number = Column(String(50))
    status = Column(SQLEnum(TransactionStatus), default=TransactionStatus.PENDING)
    sanction_category = Column(String(100))
    sanction_data = Column(JSON)
    watchlist_category = Column(String(100))
    watchlist_data = Column(Text)
    compliance_category = Column(String(100))
    compliance_data = Column(Text)
    photo = Column(Text)
    cif_id = Column(String(50))
    corporateid = Column(String(50))
    entry_date = Column(DateTime)
    value_date = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class CustomerProfile(Base):
    __tablename__ = "customer_profiles"
    
    id = Column(Integer, primary_key=True, index=True)
    acct_no = Column(String(50), unique=True, index=True, nullable=False)
    acct_name = Column(String(255), nullable=False)
    risk_score = Column(Float, default=0)
    risk_level = Column(SQLEnum(RiskLevel), default=RiskLevel.LOW)
    last_transaction_id = Column(String(100))
    acct_opn_date = Column(DateTime)
    branch = Column(String(50))
    address_line = Column(Text)
    country = Column(String(100))
    mobile_no = Column(String(50))
    nrc_no = Column(String(100))
    tpin_number = Column(String(50))
    cercn = Column(String(50))
    schm_code = Column(String(50))
    schm_desc = Column(String(255))
    tran_date = Column(DateTime)
    tran_crncy_code = Column(String(10))
    dr_cr_indicator = Column(String(10))
    tran_amt = Column(Float)
    tran_particular = Column(Text)
    tran_rmks = Column(Text)
    
    # Transaction limits
    a_cash_excp_amt_lim = Column(Float, default=0)
    a_clg_excp_amt_lim = Column(Float, default=0)
    a_xfer_excp_amt_lim = Column(Float, default=0)
    a_cash_cr_excp_amt_lim = Column(Float, default=0)
    a_clg_cr_excp_amt_lim = Column(Float, default=0)
    a_xfer_cr_excp_amt_lim = Column(Float, default=0)
    s_cash_abnrml_amt_lim = Column(Float, default=0)
    s_clg_abnrml_amt_lim = Column(Float, default=0)
    s_xfer_abnrml_amt_lim = Column(Float, default=0)
    s_cash_dr_lim = Column(Float, default=0)
    s_xfer_dr_lim = Column(Float, default=0)
    s_clg_dr_lim = Column(Float, default=0)
    s_cash_cr_lim = Column(Float, default=0)
    s_xfer_cr_lim = Column(Float, default=0)
    s_clg_cr_lim = Column(Float, default=0)
    s_cash_dr_abnrml_lim = Column(Float, default=0)
    s_clg_dr_abnrml_lim = Column(Float, default=0)
    s_xfer_dr_abnrml_lim = Column(Float, default=0)
    s_new_acct_abnrml_tran_amt = Column(Float, default=0)
    
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class RawTransaction(Base):
    __tablename__ = "raw_transactions"
    
    id = Column(Integer, primary_key=True, index=True)
    acct_no = Column(String(50), index=True, nullable=False)
    acct_name = Column(String(255))
    risk_score = Column(Float, default=0)
    risk_level = Column(SQLEnum(RiskLevel), default=RiskLevel.LOW)
    tran_id = Column(String(100), index=True)
    acct_opn_date = Column(DateTime)
    branch = Column(String(50))
    address_line = Column(Text)
    country = Column(String(100))
    mobile_no = Column(String(50))
    nrc_no = Column(String(100))
    tpin_number = Column(String(50))
    cercn = Column(String(50))
    schm_code = Column(String(50))
    schm_desc = Column(String(255))
    tran_date = Column(DateTime)
    tran_crncy_code = Column(String(10))
    dr_cr_indicator = Column(String(10))
    tran_amt = Column(Float)
    tran_particular = Column(Text)
    tran_rmks = Column(Text)
    
    # Transaction limits
    a_cash_excp_amt_lim = Column(Float, default=0)
    a_clg_excp_amt_lim = Column(Float, default=0)
    a_xfer_excp_amt_lim = Column(Float, default=0)
    a_cash_cr_excp_amt_lim = Column(Float, default=0)
    a_clg_cr_excp_amt_lim = Column(Float, default=0)
    a_xfer_cr_excp_amt_lim = Column(Float, default=0)
    s_cash_abnrml_amt_lim = Column(Float, default=0)
    s_clg_abnrml_amt_lim = Column(Float, default=0)
    s_xfer_abnrml_amt_lim = Column(Float, default=0)
    s_cash_dr_lim = Column(Float, default=0)
    s_xfer_dr_lim = Column(Float, default=0)
    s_clg_dr_lim = Column(Float, default=0)
    s_cash_cr_lim = Column(Float, default=0)
    s_xfer_cr_lim = Column(Float, default=0)
    s_clg_cr_lim = Column(Float, default=0)
    s_cash_dr_abnrml_lim = Column(Float, default=0)
    s_clg_dr_abnrml_lim = Column(Float, default=0)
    s_xfer_dr_abnrml_lim = Column(Float, default=0)
    s_new_acct_abnrml_tran_amt = Column(Float, default=0)
    
    photo = Column(Text)
    cif_id = Column(String(50))
    corporateid = Column(String(50))
    entry_date = Column(DateTime)
    value_date = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class Watchlist(Base):
    __tablename__ = "watchlists"
    
    id = Column(Integer, primary_key=True, index=True)
    account_number = Column(String(50), unique=True, index=True, nullable=False)
    account_name = Column(String(255))
    reason_for_monitoring = Column(Text, nullable=False)
    category = Column(String(100))
    added_by = Column(String(100))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class TransactionExemption(Base):
    __tablename__ = "transaction_exemptions"
    
    id = Column(Integer, primary_key=True, index=True)
    account_number = Column(String(50), unique=True, index=True, nullable=False)
    account_name = Column(String(255))
    exemption_reason = Column(Text)
    exempted_by = Column(String(100))
    is_active = Column(Boolean, default=True)
    expiry_date = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class TransactionLimit(Base):
    __tablename__ = "transaction_limits"
    
    id = Column(Integer, primary_key=True, index=True)
    channel = Column(String(50), nullable=False)
    type = Column(String(50), nullable=False)
    limit = Column(Float, nullable=False)
    flag_reason = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())