provider "aws" {
  region = var.region
}

module "vpc" {
  source             = "../../modules/network"
  service            = var.service
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  subnets            = var.subnets
  availability_zones = var.availability_zones
  container_port     = 80
}

# 検索用の特定タグをVPCに付与
resource "aws_ec2_tag" "vpc_tag" {
  resource_id = module.vpc.vpc_id
  key         = "FoundationLayer"
  value       = "true"
}

resource "aws_ec2_tag" "env_tag" {
  resource_id = module.vpc.vpc_id
  key         = "Environment"
  value       = var.env
}
