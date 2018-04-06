#!/usr/bin/env bash
set -e

docker-compose $COMPOSE_FILES_ARGS down --rmi local --volumes
