#!/bin/bash

# Connect to MySQL test database using the monitor user with SELECT-only access
docker exec -it test_mysql mysql -umonitor_user -pmonitor_pass test