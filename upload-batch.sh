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
  echo "Usage: ./upload-batch.sh <batch-metadata>"
  echo "Batch metadata is a multi-line text file, every row is the image URL and the bus stop name, space separated."
  echo "Image URL can be either a local file or any object that can be used as a source of 'gcloud storage cp' command."
  exit 1
}

if [[ "$#" -ne 1 ]]; then
  print_usage_and_exit
fi

filename=$1

while IFS=' ' read -ra COLUMNS; do
  source=${COLUMNS[0]}
  bus_stop_id=${COLUMNS[1]}
  destination=$(basename "$source")

  ./copy-image.sh "$source" "$destination" "$bus_stop_id"
done < "$filename"
