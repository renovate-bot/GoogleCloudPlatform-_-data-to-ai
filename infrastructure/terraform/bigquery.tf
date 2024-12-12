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

resource "google_bigquery_dataset" "bus-stop-image-processing" {
  dataset_id    = "bus_stop_image_processing"
  friendly_name = "Bus Stop Image Processing"
  location      = var.bigquery_dataset_location
}

resource "google_bigquery_connection" "image_bucket_connection" {
  connection_id = "image_bucket_connection"
  project       = var.project_id
  location      = var.bigquery_dataset_location
  depends_on = [google_project_service.bigquery_connection_api]

  cloud_resource {}
}

locals {
  connection_sa = format("serviceAccount:%s", google_bigquery_connection.image_bucket_connection.cloud_resource[0].service_account_id)
  dataset_id = google_bigquery_dataset.bus-stop-image-processing.dataset_id
}

resource "google_storage_bucket_iam_member" "connection_sa_bucket_viewer" {
  bucket = google_storage_bucket.image_bucket.name
  role    = "roles/storage.objectViewer"
  member  = local.connection_sa
  depends_on = [google_bigquery_connection.image_bucket_connection]
}

resource "google_project_iam_member" "connection_sa_vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = local.connection_sa
  depends_on = [google_bigquery_connection.image_bucket_connection]
}

resource "google_bigquery_table" "images" {
  deletion_protection = false
  dataset_id          = local.dataset_id
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
  dataset_id          = local.dataset_id
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
  dataset_id          = local.dataset_id
  table_id            = "process_watermark"
  description         = "Table with a single row which contains the timestamp the data was last processed."
  schema              = file("${path.module}/bigquery-schema/process_watermark.json")
}

resource "google_bigquery_job" "populate_process_watermark" {
  job_id     = "set_initial_process_watermark"
  depends_on = [google_bigquery_table.process_watermark]

  query {
    query = "INSERT INTO ${local.dataset_id}.${google_bigquery_table.process_watermark.table_id} VALUES (TIMESTAMP('2000-01-01 00:00:00+00'))"
    create_disposition = ""
    write_disposition = ""
  }
  location = var.bigquery_dataset_location
}

resource "google_bigquery_table" "report_watermark" {
  deletion_protection = false
  dataset_id          = local.dataset_id
  table_id            = "report_watermark"
  description         = "Table with a single row which contains the timestamp the report data was last processed."
  schema              = file("${path.module}/bigquery-schema/report_watermark.json")
}

resource "google_bigquery_job" "populate_report_watermark" {
  job_id     = "set_initial_report_watermark"
  depends_on = [google_bigquery_table.report_watermark]

  query {
    query = "INSERT INTO ${local.dataset_id}.${google_bigquery_table.report_watermark.table_id} VALUES (TIMESTAMP('2000-01-01 00:00:00+00'))"
    create_disposition = ""
    write_disposition = ""
  }
  location = var.bigquery_dataset_location
}

resource "google_bigquery_table" "incidents" {
  deletion_protection = false
  dataset_id          = local.dataset_id
  table_id            = "incidents"
  description         = "Incidents generated based on the attributes of the processed images"
  clustering          = ["bus_stop_id"]
  schema              = file("${path.module}/bigquery-schema/incidents.json")
}

data "local_file" "describe_image_prompt_config" {
  filename = "${path.module}/../../prompts/describe-image.prompt.yaml"
}

locals {
  prompt_config = yamldecode(data.local_file.describe_image_prompt_config.content)

  default_model_name = "default_model"
  pro_model_name = "pro_model"
}

resource "random_id" "job_id_suffix" {
  byte_length = 8
}

resource "google_bigquery_job" "create_default_model" {
  job_id     = "create_default_model_${random_id.job_id_suffix.hex}" 
  location = var.bigquery_dataset_location
  depends_on = [
    google_project_service.vertex_ai_api,
    google_project_iam_member.connection_sa_vertex_ai_user
  ]
  query {
    query = <<END_OF_STATEMENT
CREATE OR REPLACE MODEL `${var.project_id}.${local.dataset_id}.${local.default_model_name}`
  REMOTE WITH CONNECTION `${google_bigquery_connection.image_bucket_connection.id}`
  OPTIONS(ENDPOINT = 'gemini-1.5-flash-001');
END_OF_STATEMENT

    create_disposition = ""
    write_disposition = ""
  }
}

resource "google_bigquery_job" "create_pro_model" {
  job_id     = "create_pro_model_${random_id.job_id_suffix.hex}"
  location = var.bigquery_dataset_location
  depends_on = [
    google_project_service.vertex_ai_api,
    google_project_iam_member.connection_sa_vertex_ai_user
  ]
  query {
    query = <<END_OF_STATEMENT
CREATE OR REPLACE MODEL `${var.project_id}.${local.dataset_id}.${local.pro_model_name}`
  REMOTE WITH CONNECTION `${google_bigquery_connection.image_bucket_connection.id}`
  OPTIONS(ENDPOINT = 'gemini-1.5-pro-001');
END_OF_STATEMENT

    create_disposition = ""
    write_disposition = ""
  }
}

resource "google_bigquery_routine" "process_images_procedure" {
  dataset_id = local.dataset_id
  routine_id = "process_images"
  routine_type = "PROCEDURE"
  language = "SQL"
  depends_on = [google_bigquery_job.create_default_model]
  definition_body = <<END_OF_PROCEDURE
DECLARE last_process_time TIMESTAMP;
DECLARE new_process_time TIMESTAMP;

BEGIN TRANSACTION;

SET last_process_time = (SELECT MAX(process_time) FROM ${local.dataset_id}.${google_bigquery_table.process_watermark.table_id});
SET new_process_time = CURRENT_TIMESTAMP();

INSERT INTO ${local.dataset_id}.${google_bigquery_table.reports.table_id}
  (uri, image_created, model_used, bus_stop_id, cleanliness_level, description, is_bus_stop, number_of_people, model_response_status)
SELECT
  uri,
  updated,
  'default' AS model_used,
  (SELECT value FROM UNNEST(metadata) WHERE name = 'stop_id') AS bus_stop_id,
  CAST (JSON_EXTRACT(ml_generate_text_llm_result, '$.cleanliness_level') AS INT64) AS cleanliness_level,
  JSON_EXTRACT(ml_generate_text_llm_result, '$.description') AS description,
  CAST (JSON_EXTRACT(ml_generate_text_llm_result, '$.is_bus_stop') AS BOOL) AS is_bus_stop,
  CAST (JSON_EXTRACT(ml_generate_text_llm_result, '$.number_of_people') AS INT64) AS number_of_people,
  ml_generate_text_status AS model_response_status
FROM
  ML.GENERATE_TEXT(
    MODEL `${var.project_id}.${local.dataset_id}.${local.default_model_name}`,
    TABLE `${var.project_id}.${local.dataset_id}.${google_bigquery_table.images.table_id}`,
    STRUCT (
      """${local.prompt_config.prompt}""" AS prompt,
      ${local.prompt_config.temperature} AS temperature,
      ${local.prompt_config.max_output_tokens} AS max_output_tokens,
      TRUE AS FLATTEN_JSON_OUTPUT)
  )
WHERE content_type = "image/jpeg" AND updated > last_process_time;

-- Update the process time watermark
UPDATE `${var.project_id}.${local.dataset_id}.${google_bigquery_table.process_watermark.table_id}`
SET process_time = new_process_time
WHERE TRUE;

COMMIT TRANSACTION;
END_OF_PROCEDURE
}

resource "google_bigquery_routine" "update_incidents_procedure" {
  dataset_id = local.dataset_id
  routine_id = "update_incidents"
  routine_type = "PROCEDURE"
  language = "SQL"
  definition_body = <<END_OF_PROCEDURE
DECLARE last_process_time TIMESTAMP;
DECLARE new_process_time TIMESTAMP;

BEGIN TRANSACTION;
SET last_process_time = (SELECT MAX(process_time) FROM ${local.dataset_id}.${google_bigquery_table.report_watermark.table_id});
SET new_process_time = CURRENT_TIMESTAMP();

-- Main MERGE statement to update or insert incidents based on new reports
MERGE ${local.dataset_id}.${google_bigquery_table.incidents.table_id} AS target
USING (
  -- CTE to get the latest report for each bus stop
  WITH latest_reports AS (
    SELECT
      *,
      -- Assign row numbers to reports for each bus stop, ordered by update time descending
      ROW_NUMBER() OVER (PARTITION BY bus_stop_id ORDER BY image_created DESC) AS report_number
    FROM ${local.dataset_id}.${google_bigquery_table.reports.table_id}
    WHERE image_created > last_process_time
  )
  -- Main subquery to prepare data for MERGE operation
  SELECT
    lr.bus_stop_id,
    -- Determine if an incident should be resolved based on cleanliness threshold
    CASE
      WHEN lr.cleanliness_level >= 6 THEN TRUE
      ELSE FALSE
    END AS should_resolve,
    i.incident_id,
    lr.report_id,
    i.open_report_id
  FROM latest_reports lr
  -- Left join to find existing open incidents for each bus stop
  LEFT JOIN ${local.dataset_id}.${google_bigquery_table.incidents.table_id} i
    ON lr.bus_stop_id = i.bus_stop_id
    AND i.status = "OPEN"
  -- Only consider the most recent report for each bus stop
  WHERE lr.report_number = 1
) AS source
ON target.incident_id = source.incident_id

-- Update existing incidents: mark as resolved if cleanliness has improved
WHEN MATCHED AND source.should_resolve THEN
  UPDATE SET
    status = "RESOLVED",
    resolve_report_id = source.report_id

-- Insert new incidents: create for stops with low cleanliness and no open incident
WHEN NOT MATCHED AND NOT source.should_resolve THEN
  INSERT (incident_id, bus_stop_id, status, open_report_id)
  VALUES (GENERATE_UUID(), source.bus_stop_id, "OPEN", source.report_id)

-- Update existing incidents: set open_report_id if it's missing
WHEN MATCHED AND NOT source.should_resolve AND target.open_report_id IS NULL THEN
  UPDATE SET
    open_report_id = source.report_id;

-- Update the process time watermark
UPDATE ${local.dataset_id}.${google_bigquery_table.report_watermark.table_id}
SET process_time = new_process_time
WHERE TRUE;

COMMIT TRANSACTION;
END_OF_PROCEDURE
}