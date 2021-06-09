resource "kubernetes_ingress" "ingress-calcetines" {
  metadata {
    name      = "ingress-calcetines"
    namespace = "sock-shop"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      host = "calcetines.arp-proyecto-asir.com"
      http {
        path {
          backend {
            service_name = "front-end"
            service_port = 80
          }

          path = "/"
        }

      }
    }
  }
}

resource "kubernetes_ingress" "ingress-argocd" {
  metadata {
    name      = "ingress-argocd"
    namespace = "herramientas"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }

  spec {
    rule {
      host = "argocd.arp-proyecto-asir.com"
      http {
        path {
          backend {
            service_name = "argocd-server"
            service_port = 443
          }

          path = "/"
        }

      }
    }
  }
}
