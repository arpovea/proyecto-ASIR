# Despligue de Kubernetes en GCP con Terraform + Helm

En este repositorio se encuentra el TFG para el ciclo de ASIR, realizado por Adrián Rodríguez Povea.

En este proyecto se pueden encontrar los siguientes contenidos realizados con Terraform:

  - [Descripción de los distintos elementos de Terraform.](#descripción-de-los-distintos-elementos-de-terraform)

  - [Configuración de los "providers" (Google, Kubernetes, Helm).](#configuración-de-los-providers-google-kubernetes-helm)

  - [Creación de estado remoto de Terraform.](#creación-de-estado-remoto-de-terraform)

  - [Creación de VPC network y subnetwork.](#creación-de-vpc-network-y-subnetwork)

  - [Reserva de IPs.](#reserva-de-ips)

  - [Despligue de GKE.](#despligue-de-gke)

  - [Despligue de recursos y aplicaciones mediante Helm (ArgoCD, Ingress Controller).](#despligue-de-recursos-y-aplicaciones-mediante-helm-argocd-ingress-controller)

  - [Despliegue y configuración zona DNS.](#despliegue-y-configuración-zona-dns)

  - [Proyecto en Google, APIs, credenciales, roles y permisos.](#proyecto-en-google-apis-credenciales-roles-y-permisos)

  - [Tratamiento de datos sensibles.](#tratamiento-de-datos-sensibles)

  - [Comandos Terraform y gcloud.](#comandos-terraform-y-gcloud)


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

Opción interesante de los bloques de Terraform:

  - depend_on: Cuando se le quiere indicar a Terraform una orden de creación de los distintos recursos.


## Configuración de los "providers" (Google, Kubernetes, Helm).

Como se ha visto en el anterior apartado se necesita iniciar el plugin del proveedor que Terraform utilizará para comunicarse con la nube pública en este caso Google Cloud.

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

Como podemos ver primero se carga el plugin a utilizar por Terraform de Google y mediante unas credenciales (token) y parámetros se le hace objetivo a un proyecto.

A continuación, se utiliza el provider de Kuberentes:

El proveedor de Kubernetes (K8S) se utiliza para interactuar con los recursos admitidos por Kubernetes. El proveedor debe configurarse con las credenciales adecuadas antes de que se pueda utilizar. Además de la autenticacíon de la cuenta, se necesita que el cluster esté previamente creado, en este caso se utiliza GKE que se comentará más adelante.

```
# Obtener datos de la cuenta para utilizarlos. En este caso para el token de autenticación.
data "google_client_config" "current" {
}
#Configuración para poder crear recursos en kubernetes, se utiliza un provider. (Se utiliza el data anterior)
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}
```

Como se puede observar se hace uso de un tipo "data", además de las otras variables para obtener los datos de la configuración de este bloque de "provider"

También se configurará el proveedor de Helm:

El proveedor de Helm se utiliza para implementar paquetes de software en Kubernetes. El proveedor debe configurarse con las credenciales adecuadas antes de que se pueda utilizar, como en el caso anterior también necesita que el cluster este previamente creado.

```
# Configuración para desplegar mediante helm, se utiliza un provider. (Se hace uso también del data)
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

Como anteriormente se hace uso de un tipo "data" para obtener algunos de los valores para la configuración de este bloque de provider además de otras variables para obtener los certificados y endpoint del cluster.


## Creación de estado remoto de terraform.

De forma predeterminada, Terraform almacena el estado localmente en un archivo llamado "terraform.tfstate". Cuando se trabaja con Terraform en equipo, el uso de un archivo local complica el uso de Terraform porque cada usuario debe asegurarse de tener siempre los datos de estado más recientes antes de ejecutar Terraform y asegurarse de que nadie más ejecute Terraform al mismo tiempo. Por ello, se escriben los datos del estado en un almacén de datos remoto, que luego se puede compartir entre todos los miembros de un equipo.

Terraform admite el almacenamiento de este estado en Google Cloud Storage además de otras opciones, por lo que primero se realiza la creación de este recurso en el fichero "storages.tf"

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

Con este bloque de Terraform se crea el almacenamiento tipo "bucket" el cual le añadimos unas opciones, como el versionado y que se vaya borrando cuando haya 5 nuevas versiones de los ficheros almacenado.

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

Ahora se creará una Virtual Private Cloud network para utilizar en nuestro proyecto, así como una subnetwork que también utilizará nuestro cluster GKE, en este caso el fichero utilizado es "networking.tf"

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

Para exporner las aplicaciones al exterior mediante los "ingress controller" necesitamos reservar dos IPs, para ello se utiliza el fichero "ips.tf"

```
#IP fijas para los ingress
resource "google_compute_address" "ipv4_1" {
  name = "ipv4-address1"
}

resource "google_compute_address" "ipv4_2" {
  name = "ipv4-address2"
}
```
Estas IPs son asignadas por el proveedor, se puede averiguar cuáles son con los elementos "outputs" que se comentaron anteriormente.


## Despligue de GKE.

Una vez tenemos configurado el plugin del proveedor de Google y las credenciales al proyecto, es hora de crear el cluster utilizando el servicio de Google llamado GKE (Google Kubernetes Engine) se utiliza el fichero "gke.tf"

Se despliega un cluster zonal, esto quiere decir, que se lanza el cluster en una zona específica de la región, ya que si esto no se especifica se crearía un cluster regional y duplicaría los nodos por cada zona de la región, lo cual no es el propósito de este proyecto.

Además, se necesita tener el binario de "gcloud", ya que nos hará falta para la configuración del contexto en el fichero ".kube" además nos valdrá para otras gestiones mediante la consola como cambiar permisos a cuentas de servicios del proyecto.

Una vez instalado gcloud, se ejecutarán los siguientes comandos:

`gcloud init` --> El cual solicitará una serie de información como nuestro correo y el proyecto al que hacer objetivo.
`gcloud application-default login` --> Con este comando se inicia sesión con las opciones del comando anterior (abre un navegador), además hace que esta conexión sea la que se selecciona por defecto.

Ahora se realizará el comando de Terraform para aplicar la configuración del fichero, en [este](#comandos-terraform-y-gcloud) apartado se expondrán una lista de comandos de Terraform. A continuación, se verá la configuración del fichero "gke.tf"

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

Lo primero que se realiza es crear el cluster (nodo master), el cual por defecto al iniciarse crea un nodo (worker), el cual es recomendable dejar que cree (para su completo despligue) y luego lo borre, se añaden parámetros para su configuración como son:
  
  - http_load_balancing --> Balancedor por defecto del cluster
  - horizontal_pod_autoscaling --> Auto escalado horizontal de los pods

Una vez el cluster esta desplegado, no tiene ningún nodo "worker" por lo que se añadirán y configurarán con el siguiente bloque de Terraform:

```
# Creamos los nodos después de desplegar el cluster en este caso 2.
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
  # Ignoramos el "node_count" para que cuando autoescale no intente
  # modificarlo, (cuando difiere del número de nodos indicados inicialmente)
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

Además, se configura el tipo de máquina a utilizar para los nodos, en este caso el tipo "e2-medium" que consta de 1 VCPU y 4GB de RAM también nos permite realizar el autoescalado, otro tipo de máquinas no lo permite como las de la serie N1.

Una vez desplegado el cluster nos queda configurar el contexto a utilizar por "kubectl" para ello utilizaremos de nuevo "gcloud":

```
gcloud container clusters get-credentials $(terraform output -raw kubernetes_cluster_name) --zone $(terraform output -raw zone)
```

Con esto queda desplegado el cluster para poder empezar a desplegar y configurar el entorno.


## Despligue de recursos y aplicaciones mediante Helm (ArgoCD, Ingress Controller).

Una vez que se han establecido los permisos necesarios (vea sección de permisos [aquí](#proyecto-en-google-apis-credenciales-roles-y-permisos)), vamos a desplegar en primer lugar nuestro software, en este caso ArgoCD, una herramienta de GitOps, para ello, se utilizan los siguiente bloques de Terraform que están en el fichero "helm.tf"

```
# Creando namespace para argocd utlizando "kubernetes"
resource "kubernetes_namespace" "herramientas" {
  metadata {
    name = "herramientas"
  }
  depends_on = [
    google_container_node_pool.primary_nodes
  ]
}
# Creando namespace para sock-shop
resource "kubernetes_namespace" "sock_shop" {
  metadata {
    name = "sock-shop"
  }
  depends_on = [
    google_container_node_pool.primary_nodes
  ]
}
```

En primer lugar, se utiliza un bloque de Terraform que crea un par de namespaces utilizando "kubernetes" (previamente se agregó a los providers), luego con el siguiente se despliega ArgoCD

```
# Desplegando argocd con helm
resource "helm_release" "helm_argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "herramientas"
  values = [templatefile("templates/argocd.yaml.tpl", {
    SSH_Argocd = split("\n", var.SSH_Argocd )
  })]
  #values     = ["${file("values.yaml")}"]
  depends_on = [
    kubernetes_namespace.herramientas,
    google_container_node_pool.primary_nodes
  ]
}
```

Los parámetros indican el repositorio a utilizar, el "chart" de dicho repositorio, el namespace donde se tiene que desplegar y el fichero "argocd.yaml.tmp" que es un "template" para cifrar los datos sensibles mediante variables, además están los parámetros de configuración, dicho fichero está configurado de tal manera que agrega un repositorio privado y despliega una aplicación "demo" tipo microservicio.

Una vez se han desplegado las aplicaciones, se despliega mediante helm dos "ingress controller" tipo "nginx", los cuales mediantes las reglas del fichero "ingress.tf" exponen nuestras aplicaciones al exterior, utilizando las IPs que se han reservado:

```
# Desplegando ingress-controler con helm para el namespace de las herramientas
resource "helm_release" "helm_ingress_controler_herramientas" {
  name       = "ingresscontr-herram"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "herramientas"
  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.ipv4_2.address
  }
  set {
    name  = "controller.scope.enabled"
    value = true
  }
  set {
    name  = "controller.scope.namespace"
    value = "herramientas"
  }
  depends_on = [
    kubernetes_namespace.herramientas,
    google_container_node_pool.primary_nodes,
    helm_release.helm_argocd
  ]
}

# Desplegando ingress-controler con helm para el namespace de las apps
resource "helm_release" "helm_ingress_controler_sock-shop" {
  name       = "ingresscontr-calcet"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "sock-shop"
  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.ipv4_1.address
  }
  set {
    name  = "controller.scope.enabled"
    value = true
  }
  set {
    name  = "controller.scope.namespace"
    value = "sock-shop"
  }
  depends_on = [
    helm_release.helm_argocd,
    kubernetes_namespace.sock_shop
  ]
}
```

La opción mas relevante es la de "scope", ya que gracias a esta opción cada controlador es capaz de escuchar solamente en el namespace seleccionado, al desplegarse con helm, consiguiendo así que el tráfico para las herramientas de "sistemas" como la de ArgoCD, esté separado del otro "ingress controler" de la aplicación de producción.

En el fichero ingress.tf están las reglas como ya se ha mencionado, se le agrega una anotación para que busquen el controlador tipo nginx:

```
annotations = {
  "kubernetes.io/ingress.class" = "nginx"
}
```


## Despliegue y configuración zona DNS.

Antes de configurar la zona DNS se ha adquirido un dominio en "Google Domains", en el fichero dns.tf se realiza la creación de zona y se agregan los registros:

```
# Creando la zona dns
resource "google_dns_managed_zone" "parent_zone" {
  #  provider = "google-beta"
  name        = "zone-arp"
  dns_name    = "arp-proyecto-asir.com."
  description = "Zona DNS del proyecto asir"
}
```

Al crear la zona en "dns_name" se agrega el dominio.

Luego en los siguientes bloques se crean los siguientes registros, tipo "A" y tipo "CNAME":

```
#Añadiendo el registro "A" de app a la zona dns
resource "google_dns_record_set" "app_dns" {
  #  provider = "google-beta"
  managed_zone = google_dns_managed_zone.parent_zone.name
  name         = "app.arp-proyecto-asir.com."
  type         = "A"
  rrdatas      = [google_compute_address.ipv4_1.address]
  ttl          = 86400
  depends_on = [
    helm_release.helm_ingress_controler_sock-shop
  ]
}

#Añadiendo el registro "A" de tools a la zona dns 
resource "google_dns_record_set" "tools_dns" {
  #  provider = "google-beta"
  managed_zone = google_dns_managed_zone.parent_zone.name
  name         = "tools.arp-proyecto-asir.com."
  type         = "A"
  rrdatas      = [google_compute_address.ipv4_2.address]
  ttl          = 86400
  depends_on = [
    helm_release.helm_ingress_controler_herramientas
  ]
}

#Añadiendo el registro "CNAME" de calcetines a la zona dns 
resource "google_dns_record_set" "calcetines_dns" {
  #  provider = "google-beta"
  managed_zone = google_dns_managed_zone.parent_zone.name
  name         = "calcetines.arp-proyecto-asir.com."
  type         = "CNAME"
  rrdatas      = ["app.arp-proyecto-asir.com."]
  ttl          = 86400
  depends_on = [
    helm_release.helm_ingress_controler_sock-shop
  ]
}

#Añadiendo el registro "CNAME" de argocd a la zona dns 
resource "google_dns_record_set" "argocd_dns" {
  #  provider = "google-beta"
  managed_zone = google_dns_managed_zone.parent_zone.name
  name         = "argocd.arp-proyecto-asir.com."
  type         = "CNAME"
  rrdatas      = ["tools.arp-proyecto-asir.com."]
  ttl          = 86400
  depends_on = [
    helm_release.helm_ingress_controler_herramientas
  ]
}

#Añadiendo el registro "CNAME" de grafana a la zona dns 
resource "google_dns_record_set" "grafana_dns" {
  #  provider = "google-beta"
  managed_zone = google_dns_managed_zone.parent_zone.name
  name         = "grafana.arp-proyecto-asir.com."
  type         = "CNAME"
  rrdatas      = ["tools.arp-proyecto-asir.com."]
  ttl          = 86400
  depends_on = [
    helm_release.helm_ingress_controler_herramientas
  ]
}
```

Una vez realizado esto solo queda cambiar en la gestión del dominio adquirido los dns que ha proporcionado GCP para la zona que ahora se administra mediante terraform.


## Proyecto en Google, APIs, credenciales, roles y permisos.

Para realizar todas las tareas anteriores se han realizado previamente algunas configuraciones en la plataforma web de google, o por CLI:

  - Creación de proyecto:    
    Previamente se ha creado el proyecto vía web, es más sencillo sobre todo cuando es con la cuenta gratuita, ya que piden datos bancarios y demás para la creación de un nuevo proyecto.    

  - Habilitar APIs:    
    En la siguiente imagen se muestran las APIs necesarias para la creación de todos los recursos que se han mencionado anteriormente, algunas activadas por defecto otras hay que habilitarlas manualmente:    

      ![APIs](/doc/imag/APIs-enabled.png)    

  - Miembros/claves asociadas del Proyecto:    
    A continuación, se añade una captura con las cuentas de servicios existentes en el proyecto, alguna se crea automáticamente al habilitar las APIs:    

      ![cuentas-servicios-proyecto](/doc/imag/cuentas-servicios-proyecto.png)    

  - Credenciales y permisos del usuario del proyecto:    
    Las cuentas de servicio de un proyecto tiene distintos roles que le concede permisos sobre los distintos componentes de la nube, desde editor del proyecto hasta administrador de GKE, entre miles de cosas, dependiendo de lo que se quiera realizar con la cuenta de servicio, en las siguientes imágenes se verá los permisos que tiene la cuenta de servicio de nuestro proyecto, y una muestra de como se puede agregar los permisos vía web y un comando de ejemplo para hacerlo vía CLI:    

      ![permisos-proyecto](/doc/imag/permisos-proyecto.png)    

      ![agregando-permisos-proyecto](/doc/imag/agregando-permisos-proyecto.png)    
      ```
      gcloud projects add-iam-policy-binding velvety-outcome-308412 --member=serviceAccount:proyecto-asir@velvety-outcome-308412.iam.gserviceaccount.com --role=roles/container.admin
      ```    
    Para ver más datos sobre los roles distintos roles del cluster pulsa [aquí](https://cloud.google.com/kubernetes-engine/docs/how-to/iam).    

    Para el despligue y creación de recursos en el cluster, se necesita crear una serie de permisos que esta definido en el fichero "clusterrolebindig.tf" con  el  cual se le da permisos al usuario de terraform, como si fuera administrador.


## Tratamiento de datos sensibles.

En esta sección hablaremos de la herramienta "git-crypt" la cual se ha utilizado para el manejo de variables/claves sensibles. 

Los datos sensibles son el ID del proyecto y la clave SSH utilizada para la conexión con el repositorio de la aplicación, esta herramienta nos permite encriptar mediante clave GPG los ficheros seleccionados en ".gitattributes" en este caso se han colocado las varibles sensibles en "secrets.auto.tfvars" el cual esta actualmente cifrado.

A continuación, se reproducen los pasos para la instalación y configuración:

  - Instalación:    
    En esta caso en Debian:

    `sudo apt update && sudo apt install git-crypt`
  
  - Creación de claves GPG personales:

    `gpg --full-generate-key`

  - Configuración de ficheros a cifrar:    
    Se indican en el  ".gitatributes".

  - Comando de Inicio:    
    El siguiente comando inicia "git-crypt":

    `git-crypt init` 

  - Agregando las claves personales para poder cifrar/descifrar los ficheros:    

    `git-crypt add-gpg-user ID_CLAVE_GPG_PUBLICA`

  - Cifrar y descifrar los ficheros antes de los "commit":    

    `git-crypt lock`    
    `git-crypt unlock`
  
  - Ver el estado de los ficheros:    

    `git-crypt status`


## Comandos Terraform y gcloud.

Lista de parametros para Terraform [aquí](https://bit.ly/3vkZIq0).    
Lista de parametros para gcloud [aquí](https://cloud.google.com/sdk/gcloud/reference).    