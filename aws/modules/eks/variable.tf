variable "master-security" {
  type = map(string)
}

variable "master-security-rule" {
  type = map(string)
}

variable "master-role" {
  type = map(string)
}

variable "worker-role" {
  type = map(string)
}

variable "vpc" {}

variable "worker-security" {
  type = map(string)
}

variable "worker-security-rule" {
  type = map(string)
}

variable "worker-egress-security-rule" {
  type = map(string)
}

variable "worker-ingress-security-rule" {
  type = map(string)
}

variable "subnets" {
  type = list(string)
}

variable "autoscale" {
  type = map(string)
}

variable "eks" {
  type = map(string)
}

variable "env" {}
variable "service" {}
