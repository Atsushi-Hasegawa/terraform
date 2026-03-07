module "vpc-main" {
  source             = "../../../modules/network"
  service            = "project"
  env                = "staging"
  vpc_cidr           = var.vpc
  subnets            = var.subnets
  availability_zones = var.availability_zones
  container_port     = 80
}

module "app" {
  source        = "../../../modules/ec2"
  service       = "project"
  env           = "staging"
  ami           = lookup(var.ec2, "ami")
  instance_type = lookup(var.ec2, "instance_type")
  num           = lookup(var.ec2, "count")
  subnet_id     = module.vpc-main.subnet_ids
  encrypted     = lookup(var.ec2, "encrypted")
  device_name   = lookup(var.ec2, "device_name")
}

module "app-lb" {
  source            = "../../../modules/elb"
  service           = "project"
  env               = "staging"
  instance_ids      = module.app.instance_ids
  count             = module.app.instance_count
  subnets           = module.vpc-main.subnet_ids
  target_group_name = lookup(var.lb, "target_group_name")
  vpc_id            = module.vpc-main.vpc_id
  listener          = var.listener
  health_check      = var.health_check
  target_type       = "instance"
  security_groups   = [module.vpc-main.alb_sg_id]
}

# ECS専用のALB (Fargate用)
module "ecs-lb" {
  source            = "../../../modules/elb"
  service           = "project"
  env               = "staging"
  instance_ids      = []
  count             = 0
  subnets           = module.vpc-main.subnet_ids
  target_group_name = "ecs-staging-tg"
  vpc_id            = module.vpc-main.vpc_id
  listener          = var.listener
  health_check      = var.health_check
  target_type       = "ip"
  security_groups   = [module.vpc-main.alb_sg_id]
}

module "ecs-app" {
  source            = "../../../modules/ecs"
  service           = "project"
  env               = "staging"
  vpc_id            = module.vpc-main.vpc_id
  subnets           = module.vpc-main.subnet_ids
  security_group_id = module.vpc-main.ecs_sg_id
  target_group_arn  = module.ecs-lb.target_group_arn
  container_port    = 80
  image             = "nginx:latest"
}
