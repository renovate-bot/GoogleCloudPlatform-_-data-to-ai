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

resource "google_bigquery_connection" "image_bucket_connection" {
  connection_id = "image_bucket_connection"
  project       = var.project_id
  location      = var.bigquery_dataset_location
  cloud_resource {}
}

locals {
  connection_sa = format("serviceAccount:%s", google_bigquery_connection.image_bucket_connection.cloud_resource[0].service_account_id)
}

resource "google_storage_bucket_iam_member" "connection_sa_bucket_viewer" {
  bucket = google_storage_bucket.image_bucket.name
  role    = "roles/storage.objectViewer"
  member  = local.connection_sa
}

resource "google_project_iam_member" "connection_sa_vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = local.connection_sa
}

resource "google_bigquery_table" "images" {
  deletion_protection = false
  dataset_id          = google_bigquery_dataset.bus-stop-image-processing.dataset_id
  table_id            = "images"
  external_data_configuration {
    connection_id       = google_bigquery_connection.image_bucket_connection.id
    source_uris         = [format("gs://%s/images/*", google_storage_bucket.image_bucket.id)]
    object_metadata     = "SIMPLE"
    metadata_cache_mode = "MANUAL"
    autodetect          = false
  }
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
  job_id     = "reports_search_index"
  depends_on = [google_bigquery_table.reports]

  query {
    query = "CREATE SEARCH INDEX IF NOT EXISTS reports_search_index ON ${google_bigquery_table.reports.table_id} (description)"
  }
}

resource "google_bigquery_table" "process_watermark" {
  deletion_protection = false
  dataset_id          = google_bigquery_dataset.bus-stop-image-processing.dataset_id
  table_id            = "process_watermark"
  description         = "Table with a single row which contains the timestamp the data was last processed."
  schema              = file("${path.module}/bigquery-schema/process_watermark.json")
}

resource "google_bigquery_job" "populate_process_watermark" {
  job_id     = "populate_process_watermark"
  depends_on = [google_bigquery_table.process_watermark]

  query {
#  TODO: change to MERGE statement to keep only a single record in the table
    query = "INSERT INTO ${google_bigquery_table.process_watermark.table_id} VALUES (CURRENT_TIMESTAMP())"
  }
}

locals {
  default_model_name = "default_model"
  pro_model_name = "pro_model"
}

resource "google_bigquery_job" "create_default_model" {
  depends_on = [google_project_iam_member.connection_sa_vertex_ai_user]
  job_id     = "create_default_model"

  location = var.bigquery_dataset_location

  query {
    query = <<END_OF_STATEMENT
CREATE OR REPLACE MODEL `${var.project_id}.${google_bigquery_dataset.bus-stop-image-processing.dataset_id}.${local.default_model_name}`
  REMOTE WITH CONNECTION `${google_bigquery_connection.image_bucket_connection.id}`
  OPTIONS(ENDPOINT = 'gemini-1.5-flash');
END_OF_STATEMENT

    create_disposition = ""
    write_disposition = ""
  }
}

resource "google_bigquery_job" "create_pro_model" {
  depends_on = [google_project_iam_member.connection_sa_vertex_ai_user]
  job_id     = "create_pro_model"

  location = var.bigquery_dataset_location

  query {
    query = <<END_OF_STATEMENT
CREATE OR REPLACE MODEL `${var.project_id}.${google_bigquery_dataset.bus-stop-image-processing.dataset_id}.${local.pro_model_name}`
  REMOTE WITH CONNECTION `${google_bigquery_connection.image_bucket_connection.id}`
  OPTIONS(ENDPOINT = 'gemini-1.5-pro');
END_OF_STATEMENT

    create_disposition = ""
    write_disposition = ""
  }
}


#resource "google_bigquery_routine" "process_images_procedure" {
#dataset_id = google_bigquery_dataset.bus-stop-image-processing.dataset_id
#routine_id = "process_images"
#routine_type = "PROCEDURE"
#language = "SQL"
#definition_body = <<END_OF_PROCEDURE
#CREATE FUNCTION process_images
#
#BEGIN TRANSACTION;
#DECLARE last_process_time TIMESTAMP;
#DECLARE new_process_time TIMESTAMP;
#SET last_process_time = (SELECT MAX(process_time) FROM ${google_bigquery_table.process_watermark.id});
#SET new_process_time = CURRENT_TIMESTAMP();
#
#INSERT INTO ${google_bigquery_table.reports.id}
#SELECT
#  GENERATE_UUID() as report_id,
#  uri,
#  (SELECT value FROM UNNEST(metadata) WHERE name = 'stop_id') AS bus_stop_id,
#  CAST (JSON_EXTRACT(ml_generate_text_llm_result, '$.cleanliness_level') AS INT64) AS cleanliness_level,
#  JSON_EXTRACT(ml_generate_text_llm_result, '$.description') AS description,
#FROM
#  ML.GENERATE_TEXT(
#   MODEL `multimodal.gemini_1_5_flash`,
#   TABLE ${google_bigquery_table.images.id},
#   STRUCT (
#   '''
#Analyse this image of a bus stop and provide the details below.
#Return your answer in JSON format as follows. Do not include JSON decorators.
#{
#    "cleanliness_level": Integer, # Rate the cleanliness of this bus stop (From 0="Extremely dirty" to 10="Extremely clean"). Focus on literring and broken items.
#    "description": String, # Details about what you see in the image in terms of cleanliness
#}
#   ''' AS PROMPT,
#   0.2 AS temperature,
#   TRUE AS FLATTEN_JSON_OUTPUT)
#  )
#WHERE content_type = "image/jpeg" AND updated > last_process_time;
#
#-- Update the process time watermark
#UPDATE `multimodal.object_watermark`
#SET process_time = new_process_time
#WHERE TRUE;
#
#COMMIT TRANSACTION;
#END
#END_OF_PROCEDURE
#}