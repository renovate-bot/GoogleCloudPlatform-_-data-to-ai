# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_bigquery_dataset" "bus-stop-image-processing" {
  dataset_id    = "bus_stop_image_processing"
  friendly_name = "Bus Stop Image Processing"
  location      = var.bigquery_dataset_location
}

resource "google_bigquery_table" "reports" {
  deletion_protection = false
  dataset_id          = google_bigquery_dataset.bus-stop-image-processing.dataset_id
  table_id            = "reports"
  description         = "Results of data extraction for an individual image"
  clustering          = ["bus_stop_id"]
  schema              = file("${path.module}/bigquery-schema/reports.json")
}

resource "google_bigquery_job" "reports_search_index" {
  job_id = "reports_search_index"

  query {
    query = "CREATE SEARCH INDEX IF NOT EXISTS reports_search_index ON ${google_bigquery_table.reports.table_id} (description)"
  }
}
