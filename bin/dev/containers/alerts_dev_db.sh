#!/bin/bash

# Connect to the alerts_dev database 
docker-compose exec db psql -U postgres -d alerts_dev