variable "nexus_image" {
  type    = string
  default = "sonatype/nexus3:3.95.1"
}

variable "nexus_storage_size" {
  type    = string
  default = "10Gi"
}

variable "nexus_cpu_request" {
  type    = string
  default = "500m"
}

variable "nexus_memory_request" {
  type    = string
  default = "1.5Gi"
}

variable "nexus_cpu_limit" {
  type    = string
  default = "2"
}

variable "nexus_memory_limit" {
  type    = string
  default = "2.5Gi"
}
