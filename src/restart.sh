#!/usr/bin/env bash
set -e

source $YODA_PATH/lib/container.sh
containers=$(get_containers "$@")

$YODA_BIN compose > /dev/null
docker-compose $COMPOSE_FILES_ARGS restart -t $STOP_WAIT_TIMEOUT ${containers[*]}
