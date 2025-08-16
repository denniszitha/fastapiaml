-- Create database and user for AML system
CREATE USER aml_user WITH PASSWORD 'aml_password';
CREATE DATABASE aml_database OWNER aml_user;
GRANT ALL PRIVILEGES ON DATABASE aml_database TO aml_user;

-- Connect to the aml_database
\c aml_database;

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO aml_user;