module "vpc" {
  source             = "../../modules/network"
  service            = var.service
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  subnets            = var.subnets
  availability_zones = var.availability_zones
  container_port     = 80
}

# 共通タグやDI用のタグをここで制御
resource "aws_ec2_tag" "vpc_tag" {
  resource_id = module.vpc.vpc_id
  key         = "FoundationLayer"
  value       = "true"
}

output "vpc_id" { value = module.vpc.vpc_id }
output "subnet_ids" { value = module.vpc.subnet_ids }
output "app_sg_id" { value = module.vpc.ecs_sg_id }
output "alb_sg_id" { value = module.vpc.alb_sg_id }
