# VPC
resource "google_compute_network" "vpc_proyecto_asir" {
  name = "proyecto-asir-network"
}

# Subnet
resource "google_compute_subnetwork" "subnet_proyecto_asir" {
  name          = "subnet-proyecto-asir"
  region        = "europe-west1"
  network       = google_compute_network.vpc_proyecto_asir.name
  ip_cidr_range = "10.10.0.0/24"
}
