#!/usr/bin/env bash
set -e

update_yodarc() {
  sed "s/{{name}}/$COMPOSE_PROJECT_NAME/g;s/{{yoda_version}}/$YODA_SOURCE_VERSION/g;s/{{compose_file_version}}/$COMPOSE_FILE_VERSION/g" $YODA_PATH/templates/yodarc > $DOCKER_ROOT/.yodarc

}
