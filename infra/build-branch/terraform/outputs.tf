output "nexus_namespace" {
  value = kubernetes_namespace.build.metadata[0].name
}

output "nexus_service" {
  value = kubernetes_service.nexus.metadata[0].name
}

output "nexus_web_url" {
  value = "http://192.168.184.128:31971"
}

output "nexus_docker_url" {
  value = "192.168.184.128:31972"
}
