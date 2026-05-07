variable "zone" {}

variable "network" {
  type = map(string)
}

variable "firewall" {
  type = list(string)
}

variable "region" {}
variable "env" {}
variable "service" {}
