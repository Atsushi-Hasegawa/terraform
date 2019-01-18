variable "vpc_network_name" {}
variable "subnetwork_name" {}
variable "subnetwork_cidr_range" { default = "10.0.0.0/8" }
variable "region" {}
variable "env" {}
variable "service" {}

resource "google_compute_network" "vpc-network" {
  name = "${var.vpc_network_name}"
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "subnetwork" {
  name = "${var.subnetwork_name}"
  ip_cidr_range = "${var.subnetwork_cidr_range}"
  network = "${google_compute_network.vpc-network.self_link}"
  region = "${var.region}"
}

output "subnetwork" {
  value = "${google_compute_subnetwork.subnetwork.self_link}"
}

output "network" {
  value = "${google_compute_network.vpc-network.self_link}"
}
