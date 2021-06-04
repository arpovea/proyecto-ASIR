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
resource "kubernetes_namespace" "argocd" {
    metadata {
        name = "argocd"
    }
}

# Desplegando argocd con helm
resource "helm_release" "helm_argocd" {
    name       = "argocd"
    repository = "https://argoproj.github.io/argo-helm"
    chart      = "argo-cd"
    namespace = "argocd"
    values = ["${file("values.yaml")}"]
}
