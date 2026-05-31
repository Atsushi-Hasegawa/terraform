variable "region" {
  description = "AWS region"
  type        = string
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
