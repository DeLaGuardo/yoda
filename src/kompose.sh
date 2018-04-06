#!/usr/bin/env bash
set -e

command -v kompose >/dev/null 2>&1 || { echo >&2 "kompose is not installed. Please check this link for installation instructions - http://kompose.io/"; exit 1; }
kompose convert $COMPOSE_FILES_ARGS --stdout