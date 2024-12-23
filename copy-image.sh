#!/usr/bin/env bash

#
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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
  --custom-metadata=stop_id="${bus_stop_id}"