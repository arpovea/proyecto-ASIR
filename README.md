# Despligue de Kubernetes en Google Cloud con Terraform + Helm

En este repositorio se encuentra el TFG para el ciclo de ASIR, realizado por Adrián Rodríguez Povea.

En este proyecto se pueden encontrar los siguientes contenidos realizados con Terraform:

  - [Descripción de los distintos elementos de Terraform.](#descripción-de-los-distintos-elementosdde-terraform)

  - Configuración de "providers" (Google,Kubernetes,Helm).

  - Creación de estado remoto de terraform.

  - Creación de VPC y subnet.

  - Reserva de IPs.

  - Despligue de GKE.

  - Permisos de usuario.

  - Despligue de recursos y aplicaciones mediante Helm (ArgoCD, IngressController).

### Descripción de los distintos elementos de Terraform.

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
  
