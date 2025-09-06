#!/bin/bash
# Join Sample Databases Network - Usage: ./bin/helpers/join_sample_dbs_network.sh [environment]
ENV="${1:-prod}"; docker network connect alerts-shared alerts-${ENV}_web-${ENV}.1.$(docker service ps alerts-${ENV}_web-${ENV} -q --no-trunc | head -1) && echo "✅ Connected $ENV to sample databases network"