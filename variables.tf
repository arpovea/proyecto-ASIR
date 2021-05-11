# Definición de las variables

# ID proyecto y región
variable "project_id" {
  description = "GCloud Project ID"
}

variable "region" {
  description = "Gloud Region"
}

# Kubernetes

variable "gke_num_nodes" {
#  default     = 2
  description = "number of gke nodes"
}

variable "gke_username" {
#  default     = ""
  description = "gke username"
}

variable "gke_password" {
#  default     = ""
  description = "gke password"
}