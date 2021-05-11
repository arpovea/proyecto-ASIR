# Salidas de las variables

# ID proyecto y región

output "project_id" {
  value       = var.project_id
  description = "GCloud Project ID"
}

output "region" {
  value       = var.region
  description = "GCloud Region"
}

# Kubernetes

output "gke_num_nodes" {
  value       = var.gke_num_nodes
  description = "number of gke nodes"
}

output "gke_username" {
  value       = var.gke_username
  description = "gke username"
}

output "gke_password" {
  value       = var.gke_password
  description = "gke password"
}