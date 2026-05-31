provider "aws" {
  region = var.region
}

module "network_stack" {
  source             = "../../stacks/network"
  region             = var.region
  service            = local.service
  env                = local.env
  vpc_cidr           = var.vpc_cidr
  subnets            = var.subnets
  availability_zones = var.availability_zones
}
