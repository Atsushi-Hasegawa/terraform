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

variable "count" {}

variable "instance_ids" {
  type = list(string)
}

variable "vpc_id" {}
variable "target_group_name" {}
