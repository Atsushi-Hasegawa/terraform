module "network" {
  source                = "../../../modules/network"
  service               = "project"
  env                   = "staging"
  compute_firewall_name = "${lookup(var.firewall, "compute_firewall_name")}"
  tags                  = "${lookup(var.firewall, "tags")}"
  ports                 = "${var.firewall_port}"
  region                = "${var.region}"
  zone                  = "${var.zone}"
  vpc_network_name      = "${lookup(var.network, "vpc_network_name")}"
  subnetwork_name       = "${lookup(var.network, "subnetwork_name")}"
  subnetwork_cidr_range = "${lookup(var.network, "subnetwork_cidr_range")}"
}

module "engine" {
  source    = "../../../modules/ce"
  service   = "project"
  env       = "staging"
  engine    = "${var.compute_engine}"
  container = "${var.container}"
  zone      = "${var.zone}"
  network   = "${module.network.network}"
}

module "storage" {
  source          = "../../../modules/storage"
  service         = "${var.project}"
  env             = "staging"
  storage         = "${var.storage}"
  service_account = "${var.service_account}"
}
