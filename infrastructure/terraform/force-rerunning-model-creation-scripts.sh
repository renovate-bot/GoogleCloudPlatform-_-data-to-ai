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

terraform taint random_id.text_embeddings_model_job_id_suffix
terraform taint random_id.default_model_job_id_suffix
terraform taint random_id.pro_model_job_id_suffix
terraform taint random_id.multimodal_embeddings_model_job_id_suffix