#!/usr/bin/env bash
set -e

compose_container() {
  if [[ -x "$COMPOSE_SCRIPT" ]]; then
    cat - | $COMPOSE_SCRIPT --name=$1 --sequence=$2
  else
    cat -
  fi
  echo
}

second_run=

for p in "$@"; do
  case $p in
    --second-run)
      second_run=true
      shift
      ;;
  esac
done

# Parse map
declare -A SCALE_MAP
for p in "$@"; do
  service=$(echo $p | cut -d'=' -f1)
  count=$(echo $p | cut -d'=' -f2)
  if [[ "$service" == "$count" ]]; then
    count=1
  fi
  SCALE_MAP["$service"]=$(( ${count:-1} - 1 )) # Start index using 0
done

if [[ -z "${SCALE_MAP[@]}" ]]; then
  >&2 echo "No services to build. First you should add container."
  exit 1
fi

# Parse Buildfile to get imagenames
declare -A IMAGE_MAP
mapfile -t lines < $DOCKER_ROOT/Buildfile
for line in "${lines[@]}"; do
  k=$(echo $line | cut -d: -f1)
  v=$(echo $line | grep -Eo '\-t [^ ]+' | cut -d' ' -f2)
  if [[ -n "$REGISTRY_URL" ]]; then
    v="$REGISTRY_URL/$v"
  fi
  IMAGE_MAP[$k]=$v
done

echo "# Build args: $*"
echo "version: '$COMPOSE_FILE_VERSION'"
echo 'services:'

# name, sequence
# Remove .0 suffix
get_container_name() {
  container_name="$1.$2"
  if [[ $2 == 0 ]]; then
    container_name=$1
  fi

  echo -n "$container_name"
}

adapt_link() {
  link_with_alias=$(echo "$1" | sed -E 's/^[ -]+(.*)$/\1/' | tr -d $'\n')
  link=${link_with_alias%:*}
  alias=${link_with_alias#*:}
  for n in $(seq 0 ${SCALE_MAP[$link]:-0}); do
    echo -n '  - '
    get_container_name "$link" "$n"
    if [[ $alias != $link_with_alias ]]; then
      echo -n ":$alias"
    fi
    echo
  done
}

adapt_depends_on() {
  dependant=$(echo "$1" | sed -E 's/^[ -]+(.*)$/\1/' | tr -d $'\n')
  for n in $(seq 0 ${SCALE_MAP[$dependant]}); do
    echo -n '  - '
    get_container_name "$dependant" "$n"
    echo
  done
}

context=
get_context() {
  if [[ "$line" =~ ^[a-z_]+: ]]; then
    echo -n "$line" | cut -d ':' -f1 | tr -d ' '
  else
    echo -n "$context"
  fi
}

for p in ${!SCALE_MAP[*]}; do
  for i in $(seq 0 ${SCALE_MAP[$p]:-0}); do
    container_name=$(get_container_name "$p" "$i")
    env_container_file="$DOCKER_ROOT/containers/$p/container$ENV.yml"
    container_file="$DOCKER_ROOT/containers/$p/container.yml"

    echo "  $container_name:"

    if [[ ! -f "$env_container_file" && $second_run ]]; then
      continue
    fi

    if [[ ! $second_run ]]; then
      if [[ $KOMPOSE ]]; then
        echo "    container_name: $container_name"
      else
        echo "    container_name: ${COMPOSE_PROJECT_NAME}.$container_name"
      fi
      echo "    hostname: ${HOSTNAME}.${COMPOSE_PROJECT_NAME}.$container_name"
    fi

    if [[ -f "$env_container_file" && $second_run ]]; then
      container_file="$env_container_file"
    fi
    mapfile -t lines < "$container_file"
    {
      for line in "${lines[@]}"; do
        context=$(get_context "$line")

        # Check if we using shortcut for image declaration
        if [[ "$line" =~ ^image: ]]; then
          image=$(echo "$line" | cut -d' ' -f2)
          echo "image: ${IMAGE_MAP[$image]:-$image}"
          continue
        fi

        # Convert links container name to fully qualified names
        if [[ "$context" == "links" ]]; then
          if [[ "$line" =~ ^\ *- ]]; then
            adapt_link "$line"
            continue
          fi
        fi

        # Convert depends_on container name to fully qualified names
        if [[ "$context" == "depends_on" ]]; then
          if [[ "$line" =~ ^\ *- ]]; then
            adapt_depends_on "$line"
            continue
          fi
        fi

        echo "$line"
      done

    } | sed "s/^/    /g" | compose_container $p $i
  done
done

all_used_containers=()
for p in ${!SCALE_MAP[*]}; do
  env_container_file="$DOCKER_ROOT/containers/$p/container$ENV.yml"
  container_file="$DOCKER_ROOT/containers/$p/container.yml"
  # if [[ $second_run ]]; then
  #   container_file="$env_container_file"
  # fi
  if [[ -f "$container_file" ]]; then
    all_used_containers+=("$container_file")
  fi
  if [[ -f "$env_container_file" ]]; then
    all_used_containers+=("$env_container_file")
  fi
done

networks=()

if [[ "${#all_used_containers[@]}" != "0" && `grep 'networks:' "${all_used_containers[@]}"` ]]; then
  for p in ${!SCALE_MAP[*]}; do
    for i in $(seq 0 ${SCALE_MAP[$p]:-0}); do
      container_name=$(get_container_name "$p" "$i")
      env_container_file="$DOCKER_ROOT/containers/$p/container$ENV.yml"
      container_file="$DOCKER_ROOT/containers/$p/container.yml"

      if [[ -f "$container_file" ]]; then
        mapfile -t lines < "$container_file"
        for line in "${lines[@]}"; do
          context=$(get_context "$line")

          # Handle network context
          if [[ "$context" == "networks" ]]; then
            if [[ "$line" =~ ^[\ ]{2}- || "$line" =~ ^[\ ]{2}[a-zA-Z]+ ]]; then
              network_name=$(echo "$line" | sed -E 's/^[ -]+([^:]*)([:])?/\1/' |tr -d $'\n')
              networks+=("$network_name")
            fi
          else
            continue
          fi
        done
      fi

      if [[ -f "$env_container_file" ]]; then
        mapfile -t lines < "$env_container_file"
        for line in "${lines[@]}"; do
          context=$(get_context "$line")

          # Handle network context
          if [[ "$context" == "networks" ]]; then
            if [[ "$line" =~ ^[\ ]{2}- || "$line" =~ ^[\ ]{2}[a-zA-Z]+ ]]; then
              network_name=$(echo "$line" | sed -E 's/^[ -]+([^:]*)([:])?/\1/' |tr -d $'\n')
              networks+=("$network_name")
            fi
          else
            continue
          fi
        done
      fi

    done
  done

  if [[ "${#networks[@]}" != "0" ]]; then
    echo "networks:"
    for network_name in `tr ' ' '\n' <<< "${networks[@]}" | sort -u | tr '\n' ' '`; do
      echo "  $network_name:"

      env_network_file="$DOCKER_ROOT/networks/$network_name/network$ENV.yml"
      network_file="$DOCKER_ROOT/networks/$network_name/network.yml"

      if [[ -f "$env_network_file" && $second_run ]]; then
        network_file="$env_network_file"
      fi

      if [[ -f "$network_file" ]]; then
        mapfile -t lines < "$network_file"
        {
          for line in "${lines[@]}"; do
            echo "$line"
          done
        } | sed "s/^/    /g" | cat -
      fi
    done
  fi
fi
