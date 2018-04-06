#!/usr/bin/env bash
set -e

source $YODA_PATH/lib/container.sh
containers=$(get_containers "$@")

$YODA_BIN compose > /dev/null
docker-compose -f $MAIN_COMPOSE_FILE -f $COMPOSE_FILE logs -f --tail="50" ${containers[*]}
