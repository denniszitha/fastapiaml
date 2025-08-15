from typing import Dict, Any, Optional
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class RiskScoringService:
    """Service for evaluating transaction risk scores"""
    
    def __init__(self):
        self.risk_factors = {
            'high_amount': {'weight': 0.3, 'threshold': 10000},
            'unusual_pattern': {'weight': 0.2},
            'watchlist': {'weight': 0.25},
            'country_risk': {'weight': 0.15},
            'account_age': {'weight': 0.1}
        }
    
    def evaluate_risk(self, transaction_data: Dict[str, Any], case_number: str) -> Dict[str, Any]:
        """
        Evaluate risk score for a transaction
        
        Args:
            transaction_data: Transaction information
            case_number: Case reference number
            
        Returns:
            Dictionary containing risk_score and risk_level
        """
        try:
            risk_score = 0.0
            risk_factors_detected = []
            
            # Check transaction amount
            amount = float(transaction_data.get('tran_amt', 0))
            if amount > self.risk_factors['high_amount']['threshold']:
                risk_score += self.risk_factors['high_amount']['weight'] * (amount / 100000)
                risk_factors_detected.append('high_amount_transaction')
            
            # Check account age (new accounts are higher risk)
            if transaction_data.get('acct_opn_date'):
                account_open_date = self._parse_date(transaction_data['acct_opn_date'])
                if account_open_date:
                    days_since_opening = (datetime.now() - account_open_date).days
                    if days_since_opening < 90:  # Less than 3 months old
                        risk_score += self.risk_factors['account_age']['weight'] * (1 - days_since_opening/90)
                        risk_factors_detected.append('new_account')
            
            # Check transaction limits
            risk_score += self._check_limit_breaches(transaction_data)
            
            # Check transaction patterns
            if self._is_unusual_pattern(transaction_data):
                risk_score += self.risk_factors['unusual_pattern']['weight']
                risk_factors_detected.append('unusual_pattern')
            
            # Normalize risk score to 0-100
            risk_score = min(risk_score * 100, 100)
            
            # Determine risk level
            risk_level = self._determine_risk_level(risk_score)
            
            return {
                'risk_score': round(risk_score, 2),
                'risk_level': risk_level,
                'risk_factors': risk_factors_detected,
                'case_number': case_number,
                'evaluated_at': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error evaluating risk: {str(e)}")
            return {
                'risk_score': 0,
                'risk_level': 'low',
                'error': str(e)
            }
    
    def _check_limit_breaches(self, transaction_data: Dict[str, Any]) -> float:
        """Check if transaction breaches any limits"""
        breach_score = 0.0
        amount = float(transaction_data.get('tran_amt', 0))
        
        # Check various limit types
        limit_fields = [
            'a_cash_excp_amt_lim', 'a_clg_excp_amt_lim', 'a_xfer_excp_amt_lim',
            's_cash_abnrml_amt_lim', 's_clg_abnrml_amt_lim', 's_xfer_abnrml_amt_lim'
        ]
        
        for field in limit_fields:
            limit = float(transaction_data.get(field, 0))
            if limit > 0 and amount > limit:
                breach_score += 0.05  # Add 5% for each limit breach
        
        return min(breach_score, 0.3)  # Cap at 30% contribution
    
    def _is_unusual_pattern(self, transaction_data: Dict[str, Any]) -> bool:
        """Detect unusual transaction patterns"""
        # Check for round amounts (potential structuring)
        amount = float(transaction_data.get('tran_amt', 0))
        if amount > 1000 and amount % 1000 == 0:
            return True
        
        # Check for unusual transaction remarks
        remarks = transaction_data.get('tran_rmks', '').lower()
        suspicious_keywords = ['cash', 'urgent', 'immediate', 'confidential']
        if any(keyword in remarks for keyword in suspicious_keywords):
            return True
        
        return False
    
    def _determine_risk_level(self, risk_score: float) -> str:
        """Determine risk level based on score"""
        if risk_score >= 75:
            return 'critical'
        elif risk_score >= 50:
            return 'high'
        elif risk_score >= 25:
            return 'medium'
        return 'low'
    
    def _parse_date(self, date_str: Any) -> Optional[datetime]:
        """Parse date string to datetime object"""
        if isinstance(date_str, datetime):
            return date_str
        
        if not date_str:
            return None
        
        date_formats = [
            '%Y-%m-%d',
            '%Y-%m-%d %H:%M:%S',
            '%d/%m/%Y',
            '%m/%d/%Y'
        ]
        
        for fmt in date_formats:
            try:
                return datetime.strptime(str(date_str), fmt)
            except ValueError:
                continue
        
        return None