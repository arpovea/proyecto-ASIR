#Versión del proveedor que utiliza terraform.
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.66.1"
    }
  }
}

#Credenciales para conectarse a google.
provider "google" {

  credentials = file("claveacceso.json")

  project = var.project_id
  region  = var.region
  zone    = var.zone
}

#Estado remoto de terraform.
terraform {
  backend "gcs" {
    bucket  = "terraform-bucket-proyecto-asir"
    prefix  = "terraform/state/default.tfstate"
    credentials = "claveacceso.json"
  }
}

# Configuración para poder desplegar en kubernetes tipo kubectl, se utiliza un provider.
data "google_client_config" "current" {
}

provider "kubernetes" {
  host = "https://${google_container_cluster.primary.endpoint}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
  token = "${data.google_client_config.current.access_token}"
}

# Configuración para desplegar con mediante helm, se utiliza un provider.
provider "helm" {

  kubernetes {
    host                   = "${google_container_cluster.primary.endpoint}"
    token                  = "${data.google_client_config.current.access_token}"

    client_certificate     = "${base64decode(google_container_cluster.primary.master_auth.0.client_certificate)}"
    client_key             = "${base64decode(google_container_cluster.primary.master_auth.0.client_key)}"
    cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
  }
}
