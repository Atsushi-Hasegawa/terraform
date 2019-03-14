variable "master-security" {
  type = "map"
}

variable "master-security-rule" {
  type = "map"
}

variable "master-role" {
  type = "map"
}

variable "worker-role" {
  type = "map"
}

variable "vpc" {}

variable "worker-security" {
  type = "map"
}

variable "worker-security-rule" {
  type = "map"
}

variable "worker-egress-security-rule" {
  type = "map"
}

variable "worker-ingress-security-rule" {
  type = "map"
}

variable "subnets" { type = "list" }

variable "autoscale" {
  type = "map"
}

variable "eks" {
  type = "map"
}

variable "env" {}
variable "service" {}
