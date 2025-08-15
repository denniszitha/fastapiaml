from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, Date
from sqlalchemy.sql import func
from app.db.base import Base

class Country(Base):
    __tablename__ = "countries"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=True)
    country_short = Column(String(255), nullable=True)
    risk_level = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class HighRiskCountry(Base):
    __tablename__ = "high_risk_countries"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=True)
    country_short = Column(String(255), nullable=True)
    risk_level = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class Currency(Base):
    __tablename__ = "currencies"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=True)
    code = Column(String(255), nullable=True)
    symbol = Column(String(255), nullable=True)
    exchange_rate = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class Branch(Base):
    __tablename__ = "branches"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class RiskLevel(Base):
    __tablename__ = "risk_levels"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=True)
    score_range = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class AccountType(Base):
    __tablename__ = "account_types"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=True)
    risk_level = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class InternalSanctionList(Base):
    __tablename__ = "internal_sanction_lists"
    
    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String(255), nullable=False)
    also_known_as = Column(Text, nullable=True)
    date_of_birth = Column(String(255), nullable=True)
    place_of_birth = Column(String(255), nullable=True)
    nationality = Column(String(255), nullable=True)
    passport_number = Column(String(255), nullable=True)
    national_id = Column(String(255), nullable=True)
    address = Column(Text, nullable=True)
    sanction_type = Column(String(255), nullable=True)
    listing_date = Column(Date, nullable=True)
    reason = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())