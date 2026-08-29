resource "kubernetes_deployment" "nexus" {
  metadata {
    name      = "nexus"
    namespace = kubernetes_namespace.build.metadata[0].name
    labels = {
      app = "nexus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nexus"
      }
    }

    template {
      metadata {
        labels = {
          app = "nexus"
        }
      }

      spec {
        security_context {
          fs_group               = 200
          fs_group_change_policy = "OnRootMismatch"
        }

        container {
          name  = "nexus"
          image = var.nexus_image

          port {
            name           = "http"
            container_port = 8081
            protocol       = "TCP"
          }

          port {
            name           = "docker"
            container_port = 8082
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = var.nexus_cpu_request
              memory = var.nexus_memory_request
            }
            limits = {
              cpu    = var.nexus_cpu_limit
              memory = var.nexus_memory_limit
            }
          }

          volume_mount {
            name       = "nexus-data"
            mount_path = "/nexus-data"
          }

          startup_probe {
            http_get {
              path   = "/"
              port   = 8081
              scheme = "HTTP"
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 60
          }

          readiness_probe {
            http_get {
              path   = "/"
              port   = 8081
              scheme = "HTTP"
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 6
          }

          liveness_probe {
            http_get {
              path   = "/"
              port   = 8081
              scheme = "HTTP"
            }
            period_seconds    = 30
            timeout_seconds   = 5
            failure_threshold = 6
          }
        }

        volume {
          name = "nexus-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.nexus.metadata[0].name
          }
        }
      }
    }
  }
}
