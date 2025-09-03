-- Create read-only monitor user for MySQL database
-- This file creates a monitor user with read-only permissions for security

-- Create the monitor user
CREATE USER IF NOT EXISTS 'monitor_user'@'%' IDENTIFIED BY 'monitor_pass';

-- Grant SELECT access to all databases (you can restrict this further if needed)
GRANT SELECT ON *.* TO 'monitor_user'@'%';

-- Grant usage (connection) privilege
GRANT USAGE ON *.* TO 'monitor_user'@'%';

-- Flush privileges to apply changes
FLUSH PRIVILEGES;

-- Show the created user
SELECT User, Host FROM mysql.user WHERE User = 'monitor_user';