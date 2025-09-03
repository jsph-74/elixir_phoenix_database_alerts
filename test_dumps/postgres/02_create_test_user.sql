-- Create read-only monitor user for PostgreSQL database
-- This file creates a monitor user with read-only permissions for security

-- Connect to the test database first
\c test;

-- Create the monitor user with password
CREATE USER monitor_user WITH PASSWORD 'monitor_pass';

-- Grant connection permissions to the test database
GRANT CONNECT ON DATABASE test TO monitor_user;

-- Grant usage on the public schema
GRANT USAGE ON SCHEMA public TO monitor_user;

-- Grant SELECT permissions on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitor_user;

-- Grant SELECT permissions on all sequences (for serial columns)
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO monitor_user;

-- Grant SELECT permissions on any future tables created in the public schema
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO monitor_user;

-- Grant SELECT permissions on any future sequences created in the public schema  
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO monitor_user;

-- Verify the user was created successfully
SELECT usename, usecreatedb, usesuper FROM pg_user WHERE usename = 'monitor_user';