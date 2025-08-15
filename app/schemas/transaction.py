from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Dict, Any, List
from datetime import datetime
from enum import Enum

class RiskLevelEnum(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class TransactionStatusEnum(str, Enum):
    SUSPICIOUS = "suspicious"
    NOT_COMPLIANT = "not compliant"
    COMPLIANT = "compliant"
    PENDING = "pending"
    REVIEWED = "reviewed"

class TransactionData(BaseModel):
    acct_no: str
    acct_name: str
    tran_id: str
    acct_opn_date: Optional[str] = None
    branch: Optional[str] = None
    address_line: Optional[str] = None
    country: Optional[str] = None
    mobile_no: Optional[str] = None
    nrc_no: Optional[str] = None
    tpin_number: Optional[str] = None
    cercn: Optional[str] = None
    schm_code: Optional[str] = None
    schm_desc: Optional[str] = None
    tran_date: str
    tran_crncy_code: str
    dr_cr_indicator: str
    tran_amt: float
    tran_particular: Optional[str] = None
    tran_rmks: Optional[str] = None
    
    # Limit fields
    a_cash_excp_amt_lim: float = 0
    a_clg_excp_amt_lim: float = 0
    a_xfer_excp_amt_lim: float = 0
    a_cash_cr_excp_amt_lim: float = 0
    a_clg_cr_excp_amt_lim: float = 0
    a_xfer_cr_excp_amt_lim: float = 0
    s_cash_abnrml_amt_lim: float = 0
    s_clg_abnrml_amt_lim: float = 0
    s_xfer_abnrml_amt_lim: float = 0
    s_cash_dr_lim: float = 0
    s_xfer_dr_lim: float = 0
    s_clg_dr_lim: float = 0
    s_cash_cr_lim: float = 0
    s_xfer_cr_lim: float = 0
    s_clg_cr_lim: float = 0
    s_cash_dr_abnrml_lim: float = 0
    s_clg_dr_abnrml_lim: float = 0
    s_xfer_dr_abnrml_lim: float = 0
    s_new_acct_abnrml_tran_amt: float = 0
    
    photo: Optional[str] = None
    cif_id: Optional[str] = None
    corporateid: Optional[str] = None
    entry_date: Optional[str] = None
    value_date: Optional[str] = None

class TransactionRequest(BaseModel):
    case_number: str = Field(..., max_length=24)
    compliance_category: str
    compliance_issue: Optional[str] = None
    current_transaction: TransactionData
    perm: str  # Webhook token

class RiskProfile(BaseModel):
    risk_score: float
    risk_level: RiskLevelEnum
    risk_factors: List[str]
    case_number: str
    evaluated_at: str

class TransactionResponse(BaseModel):
    success: bool
    message: str
    case_number: Optional[str] = None
    risk_profile: Optional[RiskProfile] = None
    is_suspicious: Optional[bool] = None
    flagging_reason: Optional[str] = None
    customer_profile_id: Optional[int] = None
    error: Optional[str] = None

class WatchlistCreate(BaseModel):
    account_number: str
    account_name: Optional[str] = None
    reason_for_monitoring: str
    category: Optional[str] = None
    added_by: Optional[str] = None

class WatchlistResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    account_number: str
    account_name: Optional[str]
    reason_for_monitoring: str
    category: Optional[str]
    added_by: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime]

class TransactionExemptionCreate(BaseModel):
    account_number: str
    account_name: Optional[str] = None
    exemption_reason: Optional[str] = None
    exempted_by: Optional[str] = None
    expiry_date: Optional[datetime] = None

class TransactionExemptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    account_number: str
    account_name: Optional[str]
    exemption_reason: Optional[str]
    exempted_by: Optional[str]
    is_active: bool
    expiry_date: Optional[datetime]
    created_at: datetime
    updated_at: Optional[datetime]

class TransactionLimitCreate(BaseModel):
    channel: str
    type: str
    limit: float
    flag_reason: Optional[str] = None

class TransactionLimitResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    channel: str
    type: str
    limit: float
    flag_reason: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime]

class CustomerProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    acct_no: str
    acct_name: str
    risk_score: float
    risk_level: RiskLevelEnum
    last_transaction_id: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime]

class SuspiciousCaseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    case_number: str
    account_number: str
    account_name: str
    transaction_date: datetime
    transaction_id: str
    amount: float
    status: TransactionStatusEnum
    flagging_reason: Optional[str]
    created_at: datetime