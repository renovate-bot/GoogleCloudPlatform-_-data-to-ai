#!/usr/bin/env bash

set -e
set -u

function print_usage_and_exit() {
  echo "Usage: ./copy-image.sh <source-file> <destination-name> <bus-stop-id>"
  exit 1
}

if [[ "$#" -ne 3 ]]; then
  print_usage_and_exit
fi

. ./.cloud-env.sh

source=$1
destination=$2
bus_stop_id=$3

gcloud storage cp "${source}" gs://${IMAGE_BUCKET}/images/"${destination}" \
  --custom-metadata=stop_id=${bus_stop_id}