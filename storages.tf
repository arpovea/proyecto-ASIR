resource "google_storage_bucket" "terraform_bucket" {
  name          = "terraform-bucket-proyecto-asir"
  location      = var.region
  force_destroy = true

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }
  versioning {
    enabled = true
  }
}