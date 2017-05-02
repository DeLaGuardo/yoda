#!/usr/bin/env bash
set -e
# shellcheck source=../lib/container.sh
source $YODA_PATH/lib/container.sh
source $YODA_PATH/lib/yaml.sh
source $YODA_PATH/lib/array.sh

for p in "$@"; do
  case $p in
    --rebuild)
      rebuild=1
      shift
      ;;
    --recreate)
      recreate=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
  esac
done

build_args=()
if [[ -n "$rebuild" ]]; then
  build_args+=('--rebuild')
fi

compose_args=('--no-build' '--remove-orphans')
if [[ -n "$recreate" ]]; then
  compose_args+=('--force-recreate')
fi

service_stop() {
  docker-compose stop -t $STOP_WAIT_TIMEOUT $1 || true
}

service_up() {
  docker-compose up ${compose_args[*]} -t $STOP_WAIT_TIMEOUT -d $1
}

$YODA_CMD compose > $COMPOSE_FILE
# Get images we need to build
images=$(grep image: $COMPOSE_FILE | sed 's|image:\(.*\)|\1|' | tr -d ' ' | sort | uniq)

containers=$(get_containers "$@")

$YODA_CMD build ${build_args[*]} $images

if [[ -z "$force" ]]; then
  running_containers=()
  parse_yaml "$DOCKER_ROOT/Startfile" cfg
  eval "flow=(\${cfg_${ENV}[flow]}) wait=(\${cfg_${ENV}[wait]}) stop=(\${cfg_${ENV}[stop]})"
  array_flip wait_index "${wait[@]}"

  # Stopping services first before recreating
  if [[ -n "${stop[*]}" ]]; then
    echo "Stopping: ${stop[*]}"
    service_stop "${stop[*]}"
  fi

  # Starting services using declared flow
  if [[ -n "${flow[*]}" ]]; then
    echo "Starting services by flow: ${flow[*]}"
    for service in "${flow[@]}"; do
      count=$(get_count "$service" 0)
      service=$(get_service "$service")
      service_containers=$(cat $COMPOSE_FILE | grep -E "container_name: $COMPOSE_PROJECT_NAME\.$service(\.[0-9]+)?$" | cut -d':' -f2 | cut -d'.' -f2 | tr -d ' ')
      if (( $count > 0 )); then
        printf -v join_string "%.0s- " $(seq 1 $count)
        echo "$service_containers" | paste -d ' ' $join_string | while read chunk; do
          echo "Starting chunks of $service by $count: $chunk"
          service_up "$chunk"
        done
      else
        echo "Starting all chunks of $service: $service_containers"
        service_up "$service_containers"
      fi

      # We should wait for this container?
      if [[ -n "${wait_index[$service]}" ]]; then
        echo "Waiting for: ${service_containers[*]}"
        wait_containers=$(cat $COMPOSE_FILE | grep -E "container_name: $COMPOSE_PROJECT_NAME\.$service(\.[0-9]+)?$" | cut -d':' -f2 | tr -d ' ' | tr '\n' ' ')
        docker wait $wait_containers
      fi
      running_containers+=($service_containers)
    done
  fi

  # Start rest of containers
  if [[ -n "${running_containers[*]}" ]]; then
    exclude_list=$(echo "${running_containers[*]}" | tr ' ' '\n')
    other=$(cat $COMPOSE_FILE | grep -E 'container_name: [A-Za-z_\.0-9]+$' | cut -d':' -f2 | cut -d'.' -f2 | tr -d ' ' | grep -v "$exclude_list" | tr '\n' ' ')
    echo "Starting rest of containers: $other"
    service_up "$other"
  else
    service_up "$containers"
  fi
else
  service_up "$containers"
fi
