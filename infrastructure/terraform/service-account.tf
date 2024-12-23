# Copyright 2024 Google LLC
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

# A single service account is used to both schedule processing and actually execute queries
# In many production environments two separate service accounts would be used. In this demo
# we are only using a single account.
resource "google_service_account" "data_processor_sa" {
  account_id   = "data-processor-sa"
  display_name = "Service Account to process incoming images"
}

locals {
  member_data_processor_sa = "serviceAccount:${google_service_account.data_processor_sa.email}"
}

resource "google_project_iam_member" "data_processor_sa_bigquery_job_user" {
  member  = local.member_data_processor_sa
  project = var.project_id
  role    = "roles/bigquery.jobUser"
}

resource "google_bigquery_connection_iam_member" "data_processor_sa_image_bucket_connection_access" {
  project       = var.project_id
  location      = var.bigquery_dataset_location
  connection_id = google_bigquery_connection.image_bucket_connection.connection_id
  role          = "roles/bigquery.connectionUser"
  member        = local.member_data_processor_sa
}

resource "google_bigquery_connection_iam_member" "data_processor_sa_vertex_ai_connection_access" {
  project       = var.project_id
  location      = var.bigquery_dataset_location
  connection_id = google_bigquery_connection.vertex_ai_connection.connection_id
  role          = "roles/bigquery.connectionUser"
  member        = local.member_data_processor_sa
}

resource "google_bigquery_table_iam_member" "data_processor_sa_bigquery_editor" {
  member = local.member_data_processor_sa
  role   = "roles/bigquery.dataEditor"
  dataset_id = google_bigquery_dataset.bus-stop-image-processing.dataset_id
  for_each = tomap({
    "reports" = google_bigquery_table.reports.id,
    "process_watermark" = google_bigquery_table.process_watermark.id,
    "report_watermark" = google_bigquery_table.report_watermark.id,
    "incidents" = google_bigquery_table.incidents.id,
  })
  table_id = each.value
}

# required in order to give access to the the stored procedures
resource "google_bigquery_dataset_iam_member" "data_processor_sa_bigquery_data_viewer" {
  member = local.member_data_processor_sa
  role   = "roles/bigquery.dataViewer"
  dataset_id = google_bigquery_dataset.bus-stop-image-processing.dataset_id
}
