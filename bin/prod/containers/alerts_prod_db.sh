#!/bin/bash

# Connect to the alerts_prod database 
docker-compose exec db psql -U postgres -d alerts_prod