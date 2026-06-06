variable "region" {
  description = "AWS region"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
  default     = "arn:aws:acm:ap-northeast-1:123456789012:certificate/dummy"
}

variable "project" {
  description = "Project context information"
  type        = map(string)
}

variable "ec2_config" {
  description = "Configuration for EC2 instances"
  type        = any
}

variable "lb_config" {
  description = "Configuration for Load Balancer"
  type        = any
}
