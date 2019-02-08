module "network" {
  source   = "../../../modules/network"
  service  = "project"
  env      = "staging"
  firewall = "${var.firewall}"
  region   = "${var.region}"
  zone     = "${var.zone}"
  network  = "${var.network}"
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

module "memorystore" {
  source  = "../../../modules/memorystore"
  env     = "staging"
  redis   = "${var.redis}"
  network = "${module.network.network}"
}
