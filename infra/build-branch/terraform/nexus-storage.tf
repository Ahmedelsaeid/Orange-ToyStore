resource "kubernetes_persistent_volume_claim" "nexus" {
  metadata {
    name      = "nexus-data"
    namespace = kubernetes_namespace.build.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "standard"

    resources {
      requests = {
        storage = var.nexus_storage_size
      }
    }
  }
}
