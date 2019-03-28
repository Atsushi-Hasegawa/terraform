variable "listener" {
  type = "map"
}

variable "health_check" {
  type = "map"
}

variable "env" {}
variable "service" {}

variable "subnets" {
  type = "list"
}

variable "count" {}

variable "instance_ids" {
  type = "list"
}

variable "vpc_id" {}
variable "target_group_name" {}
