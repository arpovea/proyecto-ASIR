# Despligue de Kubernetes en GCP con Terraform + Helm

En este repositorio se encuentra el TFG para el ciclo de ASIR, realizado por Adrián Rodríguez Povea.

En este proyecto se pueden encontrar los siguientes contenidos realizados con Terraform:

  - [Descripción de los distintos elementos de Terraform.](#descripción-de-los-distintos-elementos-de-terraform)

  - [Configuración de "providers" (Google,Kubernetes,Helm).](#configuración-de-providers-googlekuberneteshelm)

  - [Creación de estado remoto de Terraform.](#creación-de-estado-remoto-de-terraform)

  - [Creación de VPC network y subnetwork.](#creación-de-vpc-network-y-subnetwork)

  - [Reserva de IPs.](#reserva-de-ips)

  - [Despligue de GKE.](#despligue-de-gke)

  - [Permisos de usuario.](#permisos-de-usuario)

  - [Despligue de recursos y aplicaciones mediante Helm (ArgoCD, IngressController).](#despligue-de-recursos-y-aplicaciones-mediante-helm-argocd-ingresscontroller)


## Descripción de los distintos elementos de Terraform.

Descripción de un bloque en Terraform:

```
resource "google_compute_network" "vpc_terraform" {
  name = "terraform-network"
}
```

El primer nombre es el nombre del servicio en la nube (google), el segundo su nombre en Terraform, y el "name" es el nombre que se le asigna al crearse en la nube.

Hay distintos tipos de elementos en Terraform, los que se han utilizado son:

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

Opciones interesantes de los bloques de Terraform:

  - depend_on: Cuando se le quiere indicar a Terraform un orden de creación de los distintos recursos.

## Configuración de "providers" (Google,Kubernetes,Helm).

Como se ha visto en el anterior apartado se necesita iniciar el plugin del proveedor que Terraform utilizaŕa para comunicarse con la nube pública en este caso Google Cloud.

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

Como anteriormente se hace uso de un tipo "data" para obtener algunos de los valores para la configuración de este bloque de provider ademas de otras variables para obtener los certificados y endpoint del cluster.


## Creación de estado remoto de terraform

De forma predeterminada, Terraform almacena el estado localmente en un archivo llamado "terraform.tfstate". Cuando se trabaja con Terraform en equipo, el uso de un archivo local complica el uso de Terraform porque cada usuario debe asegurarse de tener siempre los datos de estado más recientes antes de ejecutar Terraform y asegurarse de que nadie más ejecute Terraform al mismo tiempo. por ello se escriben los datos del estado en un almacén de datos remoto,que luego se puede compartir entre todos los miembros de un equipo.

Terraform admite el almacenamiento de este estado en Google Cloud Storage ademas de otras opciones, por lo que primero se realiza la creación de este recurso en el fichero "storages.tf"

```
#Bucket para el estado remoto de terraform
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
```

En este bloque de Terraform se configura el almacenamiento tipo "bucket" el cual le añadimos unas opciones,como el versionado y que se vaya borrando cuando haya 5 nuevas versiones de lo almacenado.

El estado remoto se implementa mediante un backend, que se puede configurar en el módulo raíz de su configuración, en este caso se ha configurado en el fichero "provider.tf":

```
#Estado remoto de terraform.
terraform {
  backend "gcs" {
    bucket      = "terraform-bucket-proyecto-asir"
    prefix      = "terraform/state/default.tfstate"
    credentials = "claveacceso.json"
  }
}
```


## Creación de VPC network y subnetwork.

Ahora se creará una Virtual Private Cloud network para utilizar en nuestro proyecto, asi como una subnetwork que utilizará nuestro cluster GKE, en este caso el fichero utilizado es "networking.tf"

```
# VPC
resource "google_compute_network" "vpc_proyecto_asir" {
  name = "proyecto-asir-network"
}

# Subnet
resource "google_compute_subnetwork" "subnet_proyecto_asir" {
  name          = "subnet-proyecto-asir"
  region        = var.region
  network       = google_compute_network.vpc_proyecto_asir.name
  ip_cidr_range = "10.10.0.0/24"
}
```
Esto crea por defecto una red VPC en cada región, y luego en la región que hemos selecciondo en este caso "europe-west1" se crea la subnetwork.


## Reserva de IPs.

Para exporner las aplicaciones al exterior mediante los "ingress controller" necesitamos reservar dos IPs para ello se utiliza el fichero "ips.tf"

```
#IP fijas para los ingress
resource "google_compute_address" "ipv4_1" {
  name = "ipv4-address1"
}

resource "google_compute_address" "ipv4_2" {
  name = "ipv4-address2"
}
```
Estas IPs son asignadas por el proveedor, se puede averiguar cuales a asignado mediante los outputs que comentaremos mas adelante.


## Despligue de GKE.

Una vez tenemos configurado el plugin del proveedor de google y las credenciales al proyecto, es hora de crear nuestro cluster utilizando el servicio de google llamado GKE (Google Kubernetes Engine) se utiliza el fichero "gke.tf"

Se despliega un cluster zonal, esto quiere decir, que se despliga el cluster en una zona especifica de la región, ya que si esto no se especifica se crearía un cluster regional y duplicaría los nodos por cada zona de la región, lo cual no es el proposito de este proyecto.

Ademas se necesita tener el binario de "gcloud", ya que nos hara falta para la configuración del contexto en el fichero .kube ademas nos valdrá para otras gestiones mediante la consola como cambiar permisos a usuario del proyecto.

Una vez instalado gcloud, se ejecutaran los siguientes comandos:

`gcloud init` --> El cual solicitará una serie de información como nuestro correo y el proyecto al que hacer objetivo.
`gcloud applcation-default login` --> Con este comando se inicia sesión con las opciones del comando anterior (abre un navegador), además hace que esta conexión sea la que se selecciona por defecto.

Ahora realizariamos el comando de Terraform para aplicar la configuración del fichero, en [esta](#comandos-terraform) sección comentaremos los comandos mas usados. Hablemos de la configuración del fichero "gke.tf"

```
# GKE cluster, crea el cluster y borra el nodo por defecto.
resource "google_container_cluster" "primary" {
  name     = "proyecto-asir-gke"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  # Deshabilitamos el balanceador por defecto y el autoescalado horizontal de los pods.
  addons_config {
    http_load_balancing {
      disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = true
    }
  }

  network    = google_compute_network.vpc_proyecto_asir.name
  subnetwork = google_compute_subnetwork.subnet_proyecto_asir.name

  master_auth {
    username = var.gke_username
    password = var.gke_password

    client_certificate_config {
      issue_client_certificate = false
    }
  }
  depends_on = [
    google_compute_network.vpc_proyecto_asir,
    google_compute_subnetwork.subnet_proyecto_asir
  ]
}
```

Lo primero que se realiza es crear el cluster, el cual por defecto al iniciarse crea un nodo, el cual es recomendable dejar que cree (para su completo despligue) y luego lo borre, se añaden parametros para su configuración como son:
  
  - http_load_balancing --> Balancedor por defecto del cluster
  - horizontal_pod_autoscaling --> Auto escalado horizontal de los pods

Una vez el cluster esta desplegado, no tiene ningún nodo "worker" por lo que se añadirán y configurarán con el siguiente bloque de terraform:

```
# Creamos los nodos despues de desplegar el cluster en este caso 2.
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  # Addon GKE autoscaler tipo balanced. Autoescala hasta 5
  autoscaling {
    max_node_count = 5
    min_node_count = 2
  }
  # Ignoramos el "node_count" para que cuando autoescale no intente modificarlo, (cuando difiere del número de nodos indicados inicialmente)
  lifecycle {
    ignore_changes = [
      node_count,
    ]
  }
  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }


    # preemptible  = true
    machine_type = "e2-medium"
    tags         = ["gke-node", "proyecto-asir-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
```

Esto configura el grupo de nodos trabajadores, los cuales como se pueden ver en los comentarios se configura al principio con dos nodos iniciales, y luego pueden escalar hasta 5, el tipo de escalado es según las solicitudes de recursos (no el uso real) de los pods que se ejecutan en los nodos del grupo.

Además se configura el tipo de máquina a utilizar para los nodos, en este caso el tipo "e2-medium" que consta de 1 VCPU y 4GB de RAM también nos permite realizar el autoescalado, otro tipo de máquinas no lo permite como las de la serie N1.

Una vez desplegado el cluster nos queda configurar el contexto a utilizar por "kubectl" para ello utilizaremos de nuevo "gcloud" para ello:

`gcloud container clusters get-credentials $(terraform output -raw kubernetes_cluster_name) --zone $(terraform output -raw zone)`

Con esto queda desplegado el cluster para poder empezar a desplegar y configurar el entorno.

## Proyecto en Google, credenciales de Google, permisos, habilitación de APIS
## Permisos de usuario.
## Despligue de recursos y aplicaciones mediante Helm (ArgoCD, IngressController).
## Comandos Terraform.