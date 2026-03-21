variable "listener" {
  type = map(string)
}

variable "health_check" {
  type = map(string)
}

variable "env" {}
variable "service" {}

variable "subnets" {
  type = list(string)
}

variable "security_groups" {
  description = "List of security group IDs for the ALB"
  type        = list(string)
  default     = []
}

variable "instance_count" {
}

variable "instance_ids" {
  type = list(string)
}

variable "vpc_id" {}
variable "target_group_name" {}

variable "target_type" {
  description = "Target type for the ALB target group (instance or ip)"
  type        = string
  default     = "instance"
}
