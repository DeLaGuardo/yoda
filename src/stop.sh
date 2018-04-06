#!/usr/bin/env bash
set -e
# shellcheck source=../lib/container.sh
source $YODA_PATH/lib/container.sh
containers=$(get_containers "$@")

docker-compose $COMPOSE_FILES_ARGS stop -t $STOP_WAIT_TIMEOUT $containers
