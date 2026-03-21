variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
variable "retention_in_days" {
  type        = number
  default     = 30
  description = "cloudwatch logs retention in days"
}