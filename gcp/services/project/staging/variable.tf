variable "project" {}
variable "region" {}

provider "google" {
  credentials = "${file("../config/account.json")}"
  project = "${var.project}"
  region = "${var.region}"
}
variable zone {
  default = "asia-northeast1-a"
}

variable "firewall" {
  default = {
    compute_firewall_name = "firewall"
    tags = "web"
  }
}

variable "firewall_port" {
  type = "list"
  default = ["80", "443", "22"]
}

variable "network" {
  default = {
    vpc_network_name = "network"
    subnetwork_name  = "subnetwork"
    subnetwork_cidr_range = "192.168.0.0/20"
  }
}

variable "compute_engine" {
  default = {
    instance_name = "test-compute"
    machine_type = "n1-standard-1"
    image = "ubuntu-os-cloud/ubuntu-1804-lts"
    size_gb = 10

  }
}

variable "container" {
  default = {
    container_name = "test-container"
    container_node_pool_name = "test-container-np"
    node_count = 1
  }
}
