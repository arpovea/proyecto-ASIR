resource "google_storage_bucket" "terraform_bucket" {
  name          = "terraform-bucket-proyecto-asir"
  location      = "europe-west1"
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 3
    }
    action {
      type = "Delete"
    }
  }
}