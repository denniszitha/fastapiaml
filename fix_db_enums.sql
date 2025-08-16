-- Fix PostgreSQL enum type conflicts
-- This script safely handles existing enum types

-- Connect to the aml_database
\c aml_database;

-- Drop all tables that use the enum types (cascade)
DROP TABLE IF EXISTS transaction_limits CASCADE;
DROP TABLE IF EXISTS exemptions CASCADE;
DROP TABLE IF EXISTS watchlist CASCADE;
DROP TABLE IF EXISTS customer_profiles CASCADE;
DROP TABLE IF EXISTS suspicious_cases CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop existing enum types if they exist
DROP TYPE IF EXISTS transactionstatus CASCADE;
DROP TYPE IF EXISTS riskrating CASCADE;
DROP TYPE IF EXISTS casestatus CASCADE;
DROP TYPE IF EXISTS limittype CASCADE;

-- Grant permissions to aml_user
GRANT ALL PRIVILEGES ON SCHEMA public TO aml_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO aml_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO aml_user;