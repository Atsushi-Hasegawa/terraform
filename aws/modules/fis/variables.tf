variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "fis" {
  type = object({
    ecs = list(object({
      cluster_name   = string
      service_name   = string
      selection_mode = string
    }))
  })
}