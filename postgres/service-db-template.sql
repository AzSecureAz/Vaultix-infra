-- ====================================================================
-- TEMPLATE: Microservice Database & User Provisioning
-- ====================================================================
-- INSTRUCTIONS:
-- Replace the placeholders before running in Adminer or psql:
--   <SERVICE_USER>     -> Name of the user (e.g. auth_service_user)
--   <SERVICE_PASSWORD> -> Strong password (e.g. auth_secure_pass)
--   <SERVICE_DB>       -> Name of the database (e.g. vaultix_auth_db)
-- ====================================================================

-- 1. Create the dedicated user for the microservice
CREATE USER <SERVICE_USER> WITH ENCRYPTED PASSWORD '<SERVICE_PASSWORD>';

-- 2. Revoke connection rights from PUBLIC so non-superusers CANNOT connect to default 'postgres' database
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;

-- 3. Create the dedicated database and assign ownership to the service user
CREATE DATABASE <SERVICE_DB> OWNER <SERVICE_USER>;

-- 4. Revoke default public access from the new database (prevents other service users from accessing it)
REVOKE ALL ON DATABASE <SERVICE_DB> FROM PUBLIC;

-- 5. Grant complete privileges on the database to the service user
GRANT ALL PRIVILEGES ON DATABASE <SERVICE_DB> TO <SERVICE_USER>;

