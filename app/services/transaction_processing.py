from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
import httpx
import logging
import json

from app.models.transaction import (
    SuspiciousCase, Transaction, CustomerProfile, 
    RawTransaction, Watchlist, TransactionExemption, 
    TransactionLimit, TransactionStatus, RiskLevel
)
from app.services.risk_scoring import RiskScoringService
from app.core.config import settings

logger = logging.getLogger(__name__)

class TransactionProcessingService:
    """Service for processing and monitoring transactions"""
    
    def __init__(self, db: Session):
        self.db = db
        self.risk_scoring_service = RiskScoringService()
    
    def process_transaction(self, transaction_data: Dict[str, Any], case_number: str) -> Dict[str, Any]:
        """
        Main transaction processing method
        
        Args:
            transaction_data: Transaction details
            case_number: Case reference number
            
        Returns:
            Processing result dictionary
        """
        try:
            account_number = transaction_data.get('acct_no')
            
            # Check if transaction is exempted
            if self.is_transaction_exempted(account_number):
                logger.info(f"Transaction exempted for account: {account_number}")
                return {
                    'success': True,
                    'status': 'exempted',
                    'message': f'Transaction with account number {account_number} is exempted'
                }
            
            # Check watchlist
            watchlist_reason = self.get_watchlist_reason(account_number)
            
            # Evaluate risk
            risk_profile = self.risk_scoring_service.evaluate_risk(transaction_data, case_number)
            
            # Process customer profiling
            customer_profile = self.process_customer_profiling(transaction_data, case_number, risk_profile)
            
            # Save raw transaction
            raw_transaction = self.process_raw_transaction(transaction_data, case_number, risk_profile)
            
            # Check transaction thresholds and determine if suspicious
            is_suspicious, flagging_reason = self.check_transaction_thresholds(transaction_data)
            
            # Add watchlist reason if exists
            if watchlist_reason:
                is_suspicious = True
                flagging_reason = f"{flagging_reason}; Watchlist: {watchlist_reason}" if flagging_reason else f"Watchlist: {watchlist_reason}"
            
            # Create suspicious case if needed
            if is_suspicious or risk_profile['risk_score'] > 50:
                suspicious_case = self.create_suspicious_case(
                    transaction_data, 
                    case_number, 
                    flagging_reason or f"High risk score: {risk_profile['risk_score']}",
                    {'risk_profile': risk_profile}
                )
                
                # Queue for AI analysis if configured
                if settings.ENABLE_AI_ANALYSIS:
                    self.queue_transaction_for_ai_analysis(transaction_data)
            
            # Sync to external API if configured
            if settings.ENABLE_EXTERNAL_SYNC:
                external_response = self.sync_transaction_to_external_api(transaction_data)
            
            return {
                'success': True,
                'case_number': case_number,
                'risk_profile': risk_profile,
                'is_suspicious': is_suspicious,
                'flagging_reason': flagging_reason,
                'customer_profile_id': customer_profile.id if customer_profile else None
            }
            
        except Exception as e:
            logger.error(f"Error processing transaction: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def is_transaction_exempted(self, account_number: str) -> bool:
        """Check if account is in exemption list"""
        exemption = self.db.query(TransactionExemption).filter(
            and_(
                TransactionExemption.account_number == account_number,
                TransactionExemption.is_active == True,
                or_(
                    TransactionExemption.expiry_date == None,
                    TransactionExemption.expiry_date > datetime.now()
                )
            )
        ).first()
        return exemption is not None
    
    def get_watchlist_reason(self, account_number: str) -> Optional[str]:
        """Get watchlist reason if account is on watchlist"""
        watchlist = self.db.query(Watchlist).filter(
            and_(
                Watchlist.account_number == account_number,
                Watchlist.is_active == True
            )
        ).first()
        return watchlist.reason_for_monitoring if watchlist else None
    
    def process_customer_profiling(self, transaction_data: Dict[str, Any], case_number: str, risk_profile: Dict[str, Any]) -> Optional[CustomerProfile]:
        """Process and update customer profile"""
        try:
            # Check if profile exists
            profile = self.db.query(CustomerProfile).filter(
                CustomerProfile.acct_no == transaction_data['acct_no']
            ).first()
            
            if profile:
                # Update existing profile
                for key, value in {
                    'acct_name': transaction_data.get('acct_name'),
                    'risk_score': risk_profile['risk_score'],
                    'risk_level': RiskLevel(risk_profile['risk_level']),
                    'last_transaction_id': transaction_data.get('tran_id'),
                    **{k: transaction_data.get(k) for k in transaction_data if hasattr(CustomerProfile, k)}
                }.items():
                    if value is not None:
                        setattr(profile, key, value)
            else:
                # Create new profile
                profile = CustomerProfile(
                    acct_no=transaction_data['acct_no'],
                    acct_name=transaction_data.get('acct_name'),
                    risk_score=risk_profile['risk_score'],
                    risk_level=RiskLevel(risk_profile['risk_level']),
                    last_transaction_id=transaction_data.get('tran_id'),
                    **{k: transaction_data.get(k) for k in transaction_data if hasattr(CustomerProfile, k) and k not in ['acct_no', 'acct_name']}
                )
                self.db.add(profile)
            
            self.db.commit()
            return profile
            
        except Exception as e:
            logger.error(f"Error processing customer profile: {str(e)}")
            self.db.rollback()
            return None
    
    def process_raw_transaction(self, transaction_data: Dict[str, Any], case_number: str, risk_profile: Dict[str, Any]) -> Optional[RawTransaction]:
        """Save raw transaction data"""
        try:
            raw_transaction = RawTransaction(
                acct_no=transaction_data['acct_no'],
                risk_score=risk_profile['risk_score'],
                risk_level=RiskLevel(risk_profile['risk_level']),
                **{k: transaction_data.get(k) for k in transaction_data if hasattr(RawTransaction, k) and k != 'acct_no'}
            )
            self.db.add(raw_transaction)
            self.db.commit()
            return raw_transaction
            
        except Exception as e:
            logger.error(f"Error saving raw transaction: {str(e)}")
            self.db.rollback()
            return None
    
    def check_transaction_thresholds(self, transaction_data: Dict[str, Any]) -> tuple[bool, Optional[str]]:
        """Check if transaction exceeds configured thresholds"""
        amount = float(transaction_data.get('tran_amt', 0))
        transaction_type = transaction_data.get('dr_cr_indicator', '').upper()
        channel = self._determine_channel(transaction_data)
        
        # Get applicable limit
        limit = self.db.query(TransactionLimit).filter(
            and_(
                TransactionLimit.channel == channel,
                TransactionLimit.type == transaction_type,
                TransactionLimit.is_active == True
            )
        ).first()
        
        if not limit:
            # Try default limit
            limit = self.db.query(TransactionLimit).filter(
                and_(
                    TransactionLimit.channel == 'DEFAULT',
                    TransactionLimit.type == transaction_type,
                    TransactionLimit.is_active == True
                )
            ).first()
        
        if limit and amount > limit.limit:
            return True, limit.flag_reason or f"{transaction_type} transaction exceeds {channel} limit of {limit.limit}"
        
        return False, None
    
    def _determine_channel(self, transaction_data: Dict[str, Any]) -> str:
        """Determine transaction channel from transaction data"""
        tran_particular = transaction_data.get('tran_particular', '').lower()
        tran_rmks = transaction_data.get('tran_rmks', '').lower()
        
        if 'cash' in tran_particular or 'cash' in tran_rmks:
            return 'CASH'
        elif 'transfer' in tran_particular or 'xfer' in tran_particular:
            return 'TRANSFER'
        elif 'clearing' in tran_particular or 'clg' in tran_particular:
            return 'CLEARING'
        else:
            return 'DEFAULT'
    
    def create_suspicious_case(self, transaction_data: Dict[str, Any], case_number: str, 
                              flagging_reason: str, additional_data: Dict[str, Any]) -> Optional[SuspiciousCase]:
        """Create a suspicious case record"""
        try:
            suspicious_case = SuspiciousCase(
                case_number=case_number,
                account_number=transaction_data['acct_no'],
                account_name=transaction_data.get('acct_name'),
                account_open_date=self._parse_datetime(transaction_data.get('acct_opn_date')),
                transaction_date=self._parse_datetime(transaction_data.get('tran_date')),
                branch_code=transaction_data.get('branch'),
                address=transaction_data.get('address_line'),
                phone=transaction_data.get('mobile_no'),
                identifier=transaction_data.get('nrc_no'),
                transaction_id=transaction_data.get('tran_id'),
                currency=transaction_data.get('tran_crncy_code'),
                transaction_type=transaction_data.get('dr_cr_indicator'),
                amount=float(transaction_data.get('tran_amt', 0)),
                reference=transaction_data.get('tran_particular'),
                tpin_number=transaction_data.get('tpin_number'),
                status=TransactionStatus.SUSPICIOUS,
                flagging_reason=flagging_reason,
                sanction_category=additional_data.get('sanction_category'),
                sanction_data=additional_data.get('sanction_data'),
                watchlist_category=additional_data.get('watchlist_category'),
                watchlist_data=additional_data.get('watchlist_data'),
                compliance_category=additional_data.get('compliance_category'),
                compliance_data=additional_data.get('compliance_issue'),
                photo=transaction_data.get('photo'),
                cif_id=transaction_data.get('cif_id'),
                corporateid=transaction_data.get('corporateid'),
                entry_date=self._parse_datetime(transaction_data.get('entry_date')),
                value_date=self._parse_datetime(transaction_data.get('value_date'))
            )
            self.db.add(suspicious_case)
            self.db.commit()
            return suspicious_case
            
        except Exception as e:
            logger.error(f"Error creating suspicious case: {str(e)}")
            self.db.rollback()
            return None
    
    def sync_transaction_to_external_api(self, transaction_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Sync transaction to external API"""
        try:
            api_payload = [{
                "account_number": transaction_data['acct_no'],
                "account_name": transaction_data.get('acct_name'),
                "transaction_id": transaction_data.get('tran_id'),
                "account_open_date": str(transaction_data.get('acct_opn_date')),
                "branch_code": transaction_data.get('branch'),
                "address": transaction_data.get('address_line'),
                "nationality": transaction_data.get('country'),
                "phone": transaction_data.get('mobile_no'),
                "identifier": transaction_data.get('nrc_no'),
                "tpin_number": transaction_data.get('tpin_number'),
                "transaction_date": str(transaction_data.get('tran_date')),
                "currency": transaction_data.get('tran_crncy_code'),
                "transaction_type": transaction_data.get('dr_cr_indicator'),
                "amount": float(transaction_data.get('tran_amt', 0)),
                "reference": transaction_data.get('tran_particular'),
                "empty_field": "",
                "transaction_code": transaction_data.get('tran_rmks', ""),
                **{k: float(transaction_data.get(k, 0)) for k in [
                    'a_cash_excp_amt_lim', 'a_clg_excp_amt_lim', 'a_xfer_excp_amt_lim',
                    'a_cash_cr_excp_amt_lim', 'a_clg_cr_excp_amt_lim', 'a_xfer_cr_excp_amt_lim',
                    's_cash_abnrml_amt_lim', 's_clg_abnrml_amt_lim', 's_xfer_abnrml_amt_lim',
                    's_cash_dr_lim', 's_xfer_dr_lim', 's_clg_dr_lim',
                    's_cash_cr_lim', 's_xfer_cr_lim', 's_clg_cr_lim',
                    's_cash_dr_abnrml_lim', 's_clg_dr_abnrml_lim', 's_xfer_dr_abnrml_lim',
                    's_new_acct_abnrml_tran_amt'
                ]},
                "photo": transaction_data.get('photo'),
                "cif_id": transaction_data.get('cif_id'),
                "corporateid": transaction_data.get('corporateid'),
                "entry_date": str(transaction_data.get('entry_date')),
                "value_date": str(transaction_data.get('value_date'))
            }]
            
            with httpx.Client() as client:
                response = client.post(
                    settings.EXTERNAL_API_URL,
                    json=api_payload,
                    headers={'Content-Type': 'application/json'},
                    timeout=30.0
                )
                response.raise_for_status()
                return response.json()
                
        except Exception as e:
            logger.error(f"Error syncing to external API: {str(e)}")
            return None
    
    def queue_transaction_for_ai_analysis(self, transaction_data: Dict[str, Any]) -> bool:
        """Queue transaction for AI analysis (placeholder for actual queue implementation)"""
        try:
            logger.info(f"Queuing transaction {transaction_data.get('tran_id')} for AI analysis")
            # In production, this would send to a message queue (RabbitMQ, Redis, etc.)
            # For now, just log it
            return True
        except Exception as e:
            logger.error(f"Failed to queue AI analysis: {str(e)}")
            return False
    
    def find_related_case(self, account_number: str, transaction_type: str, 
                         default_case_number: str, period_type: str = 'daily') -> str:
        """Find related case for daily or weekly transactions"""
        query = self.db.query(SuspiciousCase).filter(
            and_(
                SuspiciousCase.account_number == account_number,
                SuspiciousCase.transaction_type == transaction_type
            )
        )
        
        if period_type == 'daily':
            result = query.filter(
                SuspiciousCase.created_at >= datetime.now().replace(hour=0, minute=0, second=0)
            ).first()
        else:  # weekly
            week_start = datetime.now() - timedelta(days=datetime.now().weekday())
            result = query.filter(
                and_(
                    SuspiciousCase.flagging_reason.like('%Weekly Transactions more than%'),
                    SuspiciousCase.created_at >= week_start
                )
            ).first()
        
        return result.case_number if result else default_case_number
    
    def _parse_datetime(self, date_value: Any) -> Optional[datetime]:
        """Parse datetime from various formats"""
        if isinstance(date_value, datetime):
            return date_value
        
        if not date_value:
            return None
        
        date_formats = [
            '%Y-%m-%d',
            '%Y-%m-%d %H:%M:%S',
            '%d/%m/%Y',
            '%m/%d/%Y'
        ]
        
        for fmt in date_formats:
            try:
                return datetime.strptime(str(date_value), fmt)
            except ValueError:
                continue
        
        return None