#!/usr/bin/env bash
set -e

for p in "$@"; do
  case $p in
    --env=*)
      shift
      ;;
  esac
done

docker-compose $COMPOSE_FILES_ARGS exec $@
