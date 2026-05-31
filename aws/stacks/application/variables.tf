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

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security group ID for the application"
  type        = string
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB"
  type        = string
}
