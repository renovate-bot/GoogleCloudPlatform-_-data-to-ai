resource "local_file" "cloud_env" {
  filename        = "${path.module}/../../.cloud-env.sh"
  file_permission = "0555"
  content         = <<EOF
IMAGE_BUCKET=${google_storage_bucket.image_bucket.name}
EOF
}