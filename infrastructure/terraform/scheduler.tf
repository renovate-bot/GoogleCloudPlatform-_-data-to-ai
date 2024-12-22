resource "google_cloud_scheduler_job" "run_bus_stop_image_processing" {
  name             = "run_bus_stop_image_processing"
  description      = "Process bus stop images"
  schedule         = var.processing_schedule
  time_zone        = "America/New_York"
  attempt_deadline = "320s"
  project          = google_cloudfunctions2_function.processing_invoker.project
  region           = google_cloudfunctions2_function.processing_invoker.location
  paused           = var.pause_scheduler

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.processing_invoker.service_config[0].uri
    body        = base64encode("Run the image processing")

    oidc_token {
      audience              = "${google_cloudfunctions2_function.processing_invoker.service_config[0].uri}/"
      service_account_email = google_service_account.data_processor_sa.email
    }
  }
}

