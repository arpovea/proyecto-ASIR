# proyecto_ASIR

## Terraform:

Descripción de un recurso en terraform:

resource "google_compute_network" "vpc_terraform" {
  name = "terraform-network"
}

El primer nombre es el nombre del servicio en la nube, el segundo su nombre en terraform, y el "name" es el nombre que se le asigna al crearse en la nube.

# Recursos creados en terraform:

- Configuración de proveedor Google Cloud.
- VPC para terraform.
- Bukect para almacenar el estado en remoto de terrafom (para trabajar en un equipo.)
- Creación de ficheros para el uso de variables.
- Habilitar Kubernetes Engine API para que terraform pueda desplegar kubernetes.