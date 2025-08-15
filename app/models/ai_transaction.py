from sqlalchemy import Column, Integer, String, DateTime, Numeric, Text
from sqlalchemy.sql import func
from app.db.base import Base

class AITransaction(Base):
    __tablename__ = "ai_transactions"
    
    id = Column(Integer, primary_key=True, index=True)
    case_number = Column(String(255), nullable=True, index=True)
    acct_no = Column(String(255), nullable=False, index=True)
    tran_id = Column(String(255), nullable=False)
    tran_amt = Column(String(255), nullable=False)
    dr_cr_indicator = Column(String(255), nullable=False)
    anomaly_flag = Column(String(255), nullable=False)
    anomaly_score = Column(String(255), nullable=False)
    findings = Column(Text, nullable=True)
    algorithm_used = Column(String(255), nullable=True)
    transaction_status = Column(Text, nullable=True)
    structuring_threshold = Column(Numeric(15, 2), nullable=True)
    limit_source = Column(String(50), nullable=True)
    tran_crncy_code = Column(String(3), default='ZMW')
    narration = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class SuspiciousActivity(Base):
    __tablename__ = "suspicious_activities"
    
    id = Column(Integer, primary_key=True, index=True)
    case_number = Column(String(255), nullable=True, index=True)
    acct_no = Column(String(255), nullable=True, index=True)
    acct_name = Column(String(255), nullable=True)
    risk_score = Column(String(255), nullable=True)
    risk_level = Column(String(255), nullable=True)
    last_transaction_id = Column(String(255), nullable=True)
    acct_opn_date = Column(String(255), nullable=True)
    branch = Column(String(255), nullable=True)
    address_line = Column(Text, nullable=True)
    country = Column(String(255), nullable=True)
    mobile_no = Column(String(255), nullable=True)
    nrc_no = Column(String(255), nullable=True)
    tpin_number = Column(String(255), nullable=True)
    cercn = Column(String(255), nullable=True)
    schm_code = Column(String(255), nullable=True)
    schm_desc = Column(String(255), nullable=True)
    tran_date = Column(String(255), nullable=True)
    tran_id = Column(String(255), nullable=True)
    tran_crncy_code = Column(String(255), nullable=True)
    dr_cr_indicator = Column(String(255), nullable=True)
    tran_amt = Column(String(255), nullable=True)
    tran_particular = Column(Text, nullable=True)
    tran_rmks = Column(Text, nullable=True)
    suspicious_reason = Column(Text, nullable=True)
    status = Column(String(255), default='pending')
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())