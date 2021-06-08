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
}

# Creando namespace para argocd
resource "kubernetes_namespace" "herramientas" {
  metadata {
    name = "herramientas"
  }
}

# Desplegando argocd con helm
resource "helm_release" "helm_argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "herramientas"
  values     = ["${file("values.yaml")}"]
}

# Desplegando ingress-controler con helm
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
}