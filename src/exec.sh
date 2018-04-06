#!/usr/bin/env bash
set -e

$YODA_BIN compose > /dev/null
echo docker-compose $COMPOSE_FILES_ARGS exec $@
