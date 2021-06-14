# Use this datasource to access the Terraform account's email for Kubernetes permissions.
data "google_client_openid_userinfo" "terraform_user" {}

resource "kubernetes_cluster_role_binding" "user" {
  metadata {
    name = "admin-user"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "User"
    name      = data.google_client_openid_userinfo.terraform_user.email
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
  depends_on = [
    google_container_node_pool.primary_nodes
  ]
}

# Creando namespace para argocd
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

# Desplegando argocd con helm
resource "helm_release" "helm_argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "herramientas"
  values = [templatefile("templates/argocd.yaml.tpl", {
    SSH_Argocd = split("\n", var.SSH_Argocd)
  })]
  #values     = ["${file("values.yaml")}"]
  depends_on = [
    kubernetes_namespace.herramientas,
    google_container_node_pool.primary_nodes
  ]
}

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