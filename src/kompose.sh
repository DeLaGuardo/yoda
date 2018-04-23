#!/usr/bin/env bash
set -e

command="convert"
args=""

for p in "$@"; do
  case $p in
    --env=*)
      args+=" $p"
      shift
      ;;
    convert|down|up)
      command="$p"
      shift
      ;;
  esac
done

command -v kompose >/dev/null 2>&1 || { echo >&2 "kompose is not installed. Please check this link for installation instructions - http://kompose.io/"; exit 1; }
docker-compose $COMPOSE_FILES_ARGS config | sed "s/^    hostname:.*$//g" > /tmp/docker-compose.yml
kompose -f /tmp/docker-compose.yml $command
rm /tmp/docker-compose.yml
