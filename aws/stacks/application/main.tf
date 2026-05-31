provider "aws" {
  region = var.region
}

# --- References (Data Sources) ---
data "aws_vpc" "common" {
  filter {
    name   = "tag:FoundationLayer"
    values = ["true"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.common.id]
  }
}

data "aws_security_group" "alb" {
  vpc_id = data.aws_vpc.common.id
  filter { name = "group-name", values = ["*-alb-sg"] }
}

data "aws_security_group" "app" {
  vpc_id = data.aws_vpc.common.id
  filter { name = "group-name", values = ["*-ecs-sg"] }
}

# --- Resource Creation ---
module "app" {
  source             = "../../modules/ec2"
  service            = var.project.service
  env                = var.project.env
  ami                = var.ec2_config.ami
  instance_type      = var.ec2_config.instance_type
  num                = var.ec2_config.count
  subnet_id          = data.aws_subnets.public.ids
  encrypted          = var.ec2_config.encrypted
  device_name        = var.ec2_config.device_name
  security_group_ids = [data.aws_security_group.app.id]
}

module "app-lb" {
  source            = "../../modules/elb"
  service           = var.project.service
  env               = var.project.env
  instance_ids      = module.app.instance_ids
  instance_count    = module.app.instance_count
  subnets           = data.aws_subnets.public.ids
  target_group_name = var.lb_config.target_group_name
  vpc_id            = data.aws_vpc.common.id
  listener          = { name = "lb", listener_port = 80, listener_protocol = "http", lb_port = 80, lb_protocol = "http" }
  health_check      = { healthy_threshold = 2, unhealthy_threshold = 2, timeout = 10, path = "HTTP:80/", interval = 60 }
  target_type       = "instance"
  security_groups   = [data.aws_security_group.alb.id]
}

# 以前 environments にあった athena などの追加モジュールもスタックに統合可能
module "athena" {
  source      = "../../modules/athena"
  project     = var.project.service
  environment = var.project.env
  region      = var.region
}
