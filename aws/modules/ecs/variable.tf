variable "env" {
  description = "Environment name (e.g., staging)"
  type        = string
}

variable "service" {
  description = "Service name (e.g., project)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = null
}

variable "container_insights" {
  description = "Whether to enable Container Insights (eBPF-based)"
  type        = string
  default     = "enabled"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnets" {
  description = "Subnet IDs for the service"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the ECS service"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN for the ECS service"
  type        = string
  default     = null
}

variable "image" {
  description = "Container image"
  type        = string
  default     = "nginx:latest"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory (MiB)"
  type        = number
  default     = 512
}

variable "enable_execute_command" {
  description = "Whether to enable ECS Exec for the service"
  type        = bool
  default     = false
}

variable "log_retention_in_days" {
  description = "Log retention period (days)"
  type        = number
  default     = 30
}
