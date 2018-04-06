#!/usr/bin/env bash
set -e
# shellcheck source=../lib/container.sh
source $YODA_PATH/lib/container.sh
containers=$(get_containers "$@")

$YODA_BIN compose > /dev/null
docker-compose $COMPOSE_FILES_ARGS stop -t $STOP_WAIT_TIMEOUT $containers
