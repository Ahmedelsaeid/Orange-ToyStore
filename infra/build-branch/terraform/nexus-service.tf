resource "kubernetes_service" "nexus" {
  metadata {
    name      = "nexus"
    namespace = kubernetes_namespace.build.metadata[0].name
  }

  spec {
    selector = { app = "nexus" }

    port {
      name        = "http"
      port        = 8081
      target_port = 8081
      node_port   = 31971
      protocol    = "TCP"
    }

    port {
      name        = "docker"
      port        = 8082
      target_port = 8082
      node_port   = 31972
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}
