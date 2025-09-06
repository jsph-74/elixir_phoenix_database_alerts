#!/bin/bash
set -e

ENV="${1:-dev}"
docker stack rm alerts-$ENV

