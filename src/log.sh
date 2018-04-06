#!/usr/bin/env bash
set -e

source $YODA_PATH/lib/container.sh
containers=$(get_containers "$@")

docker-compose $COMPOSE_FILES_ARGS logs -f --tail="50" ${containers[*]}
