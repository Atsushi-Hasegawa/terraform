provider "aws" {
  region = var.region
}

module "vpc" {
  source             = "../../modules/network"
  service            = local.service
  env                = local.env
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

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.subnet_ids
}

output "app_sg_id" {
  value = module.vpc.ecs_sg_id
}

output "alb_sg_id" {
  value = module.vpc.alb_sg_id
}
