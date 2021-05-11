terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.66.1"
    }
  }
}

provider "google" {

  credentials = file("velvety-outcome-308412-a6ea9866aa6a.json")

  project = "velvety-outcome-308412"
  region  = "europe-west1"
  zone    = "europe-west1-b"
}

terraform {
  backend "gcs" {
    bucket  = "terraform-bucket-proyecto-asir"
    prefix  = "terraform/state"
    credentials = "velvety-outcome-308412-a6ea9866aa6a.json"
  }
}