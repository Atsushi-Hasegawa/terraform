module "network" {
  source = "../../../modules/network"
  service = "project"
  env = "staging"
  compute_firewall_name = "${lookup(var.firewall, "compute_firewall_name")}"
  tags = "${lookup(var.firewall, "tags")}"
  ports = "${join(",", var.firewall_port)}"
  region = "${var.region}"
  zone = "${var.zone}"
  vpc_network_name = "${lookup(var.network, "vpc_network_name")}"
  subnetwork_name = "${lookup(var.network, "subnetwork_name")}"
  subnetwork_cidr_range = "${lookup(var.network, "subnetwork_cidr_range")}"
}

module "engine" {
  source = "../../../modules/ce"
  service = "project"
  env = "staging"
  instance_name = "${lookup(var.compute_engine, "instance_name")}"
  machine_type = "${lookup(var.compute_engine, "machine_type")}"
  image = "${lookup(var.compute_engine, "image")}"
  size_gb = "${lookup(var.compute_engine, "size_gb")}"
  container_name = "${lookup(var.container, "container_name")}"
  container_node_pool_name = "${lookup(var.container, "container_node_pool_name")}"
  node_count = "${lookup(var.container, "node_count")}"
  zone = "${var.zone}"
  network = "${module.network.network}"
  subnetwork = "${module.network.subnetwork}"
}
