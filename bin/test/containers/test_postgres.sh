#!/bin/bash

# Connect to PostgreSQL test database using the monitor user with SELECT-only access
PGPASSWORD=monitor_pass docker exec -it test_postgres psql -U monitor_user -d test