#!/usr/bin/env bash
set -e

$YODA_BIN compose > /dev/null
docker-compose -f $MAIN_COMPOSE_FILE -f $COMPOSE_FILE ps
