***

# Despligue de Kubernetes en GCP con Terraform + Helm

***

En este repositorio se encuentra el TFG para el ciclo de ASIR, realizado por Adrián Rodríguez Povea.

En este proyecto se pueden encontrar los siguientes contenidos realizados con Terraform:

  - [Descripción de los distintos elementos de Terraform.](#descripción-de-los-distintos-elementos-de-terraform)

  - [Configuración de "providers" (Google,Kubernetes,Helm).](#configuración-de-providers-googlekuberneteshelm)

  - [Creación de estado remoto de terraform.](#creación-de-estado-remoto-de-terraform)

  - [Creación de VPC y subnet.](#creación-de-vpc-y-subnet)

  - [Reserva de IPs.](#reserva-de-ips)

  - [Despligue de GKE.](#despligue-de-gke)

  - [Permisos de usuario.](#permisos-de-usuario)

  - [Despligue de recursos y aplicaciones mediante Helm (ArgoCD, IngressController).](#despligue-de-recursos-y-aplicaciones-mediante-helm-argocd-ingresscontroller)

***

## Descripción de los distintos elementos de Terraform.

Descripción de un bloque en terraform:

```
resource "google_compute_network" "vpc_terraform" {
  name = "terraform-network"
}
```

El primer nombre es el nombre del servicio en la nube (google), el segundo su nombre en terraform, y el "name" es el nombre que se le asigna al crearse en la nube.

Hay distintos tipos de elementos en terraform, los que se han utilizado son:

  - Provider:    
    Terraform se basa en complementos llamados "proveedores" para interactuar con proveedores de nube, proveedores de SaaS y otras API.
    Las configuraciones de Terraform deben declarar qué proveedores requiere para que Terraform pueda instalarlos y usarlos. Además, algunos proveedores requieren configuración (como URL de punto final, región, autenticación...) antes de que puedan usarse.

  - Resource:    
    Los recursos son los elementos más importantes del lenguaje Terraform. Cada bloque de recursos describe uno o más objetos de infraestructura, como redes virtuales, instancias o componentes de nivel superior, como registros DNS.
  
  - Data:    
    Permiten que Terraform use información definida fuera de Terraform, definida por otra configuración separada de Terraform o modificada por funciones. (APIs o recursos de los proveedores)

    El lenguaje Terraform incluye algunos tipos de bloques para solicitar o publicar valores con nombre.    
  - Variable:    
     Sirven como parámetros para un bloque de Terraform, por lo que los usuarios pueden personalizar el comportamiento sin editar la fuente.
  - Output:    
    Son valores de retorno de las variables o bloques de Terraform.

***

## Configuración de "providers" (Google,Kubernetes,Helm).

Como se ha visto en el anterior apartado se necesita iniciar el plugin del proveedor que terraform utilizaŕa para comunicarse con la nube pública en este caso Google Cloud.

Esta configuración se realiza en el fichero "provider.tf":

```
#Versión del plugin del proveedor que utiliza terraform para google.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
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
```

Como podemos ver primero se carga el plugin a utilizar por terraform de google y mediante unas credenciales(token) y parametros se le hace objetivo a un proyecto.

A continuación se utiliza el provider de Kuberentes:

El proveedor de Kubernetes (K8S) se utiliza para interactuar con los recursos admitidos por Kubernetes. El proveedor debe configurarse con las credenciales adecuadas antes de que se pueda utilizar. Ademas de la autenticacíon de la cuenta se necesita que el cluster este previamente creado en este caso se utiliza GKE que se comentará mas adelante.

```
# Obtener datos de la cuenta para utilizarlos. en este caso para el token de autenticación.
data "google_client_config" "current" {
}
#Configuración para poder crear recursos en kubernetes, se utiliza un provider. (Se utiliza el data anterior)
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}
```

Como se puede observar se hace uso de un tipo "data", ademas de las otras variables para obtener los datos de la configuración de este bloque de "provider"

También se configurará el proveedor de Helm:

El proveedor de Helm se utiliza para implementar paquetes de software en Kubernetes. El proveedor debe configurarse con las credenciales adecuadas antes de que se pueda utilizar, como en el caso anterior tambien necesita que el cluster este previamente creado.

```
# Configuración para desplegar mediante helm, se utiliza un provider. (Se hace uso tambien del data)
provider "helm" {

  kubernetes {
    host  = google_container_cluster.primary.endpoint
    token = data.google_client_config.current.access_token

    client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
    client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}
```

Como anteriormente se hace uso de un tipo "data" para obtener algunos de los valores para la configuracion de este bloque de provider ademas de otras variables para obtener los certificados y endpoint del cluster.

***

## Creación de estado remoto de terraform
## Creación de VPC y subnet.
## Reserva de IPs.
## Despligue de GKE.
## Permisos de usuario.
## Despligue de recursos y aplicaciones mediante Helm (ArgoCD, IngressController).
## Proyecto en Google, credenciales de Google, permisos, habilitación de APIS