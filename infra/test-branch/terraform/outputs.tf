output "test_namespace" { value = kubernetes_namespace.test.metadata[0].name }
