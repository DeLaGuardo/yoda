#!/usr/bin/env bash
set -e

get_containers() {
  containers=()
  for service in "$@"; do
    containers+=($(grep -oE "^  $service.[0-9]+:$" "$COMPOSE_FILES_BASE" | sed -E 's/^[[:space:]]+(.*):/\1/'))
  done

  echo ${containers[*]}
}

get_count() {
  service=$1
  default=$2

  if [[ "$service" == *"="* ]]; then
    count=$(echo "$service" | cut -d'=' -f2)
  else
    count=$default
  fi

  echo "$count"
}

get_service() {
  echo "$1" | cut -d'=' -f1
}
