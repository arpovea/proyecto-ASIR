terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.66.1"
    }
  }
}

provider "google" {

  credentials = file("velvety-outcome-308412-4680d1d3da9c.json")

  project = var.project_id
  region  = var.region
  zone    = "europe-west1-b"
}

terraform {
  backend "gcs" {
    bucket  = "terraform-bucket-proyecto-asir"
    prefix  = "terraform/state"
    credentials = "velvety-outcome-308412-4680d1d3da9c.json"
  }
}