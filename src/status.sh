#!/usr/bin/env bash
set -e

$YODA_BIN compose > /dev/null
docker-compose $COMPOSE_FILES_ARGS ps
