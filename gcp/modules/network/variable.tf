variable "zone" {}
variable "compute_firewall_name" {}

variable "ports" {
  type = "list"
}

variable "tags" {}
variable "vpc_network_name" {}
variable "subnetwork_name" {}

variable "subnetwork_cidr_range" {
  default = "10.0.0.0/8"
}

variable "region" {}
variable "env" {}
variable "service" {}
