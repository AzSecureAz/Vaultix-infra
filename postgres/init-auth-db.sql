-- ====================================================================
-- Provisioning script for Authorization Service DB & User
-- ====================================================================
-- Run this in Adminer (as superuser 'postgres') or via psql

-- 1. Create dedicated user
CREATE USER auth_user WITH ENCRYPTED PASSWORD 'auth_password';

-- 2. Revoke default connect on postgres DB
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;

-- 3. Create database owned by service user
CREATE DATABASE vaultix_auth_db OWNER auth_user;

-- 4. Secure the new database from public access
REVOKE ALL ON DATABASE vaultix_auth_db FROM PUBLIC;
GRANT ALL PRIVILEGES ON DATABASE vaultix_auth_db TO auth_user;

