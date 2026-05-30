provider "aws" {
  region = local.project.region
}

# --- Dependency Injection via Data Sources ---
# commonで作成した基盤をタグで検索して取得
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

# 特定のSGが必要な場合は名前やタグで検索（例: alb-sg）
data "aws_security_group" "alb" {
  vpc_id = data.aws_vpc.common.id
  filter {
    name   = "group-name"
    values = ["*-alb-sg"] # networkモジュールの命名規則に合わせる
  }
}

data "aws_security_group" "app" {
  vpc_id = data.aws_vpc.common.id
  filter {
    name   = "group-name"
    values = ["*-ecs-sg"] # 現状の命名
  }
}

# --- Application Layer ---

module "app" {
  source             = "../../modules/ec2"
  service            = local.project.service
  env                = local.project.env
  ami                = lookup(var.ec2, "ami")
  instance_type      = lookup(var.ec2, "instance_type")
  num                = lookup(var.ec2, "count")
  subnet_id          = data.aws_subnets.public.ids
  encrypted          = lookup(var.ec2, "encrypted")
  device_name        = lookup(var.ec2, "device_name")
  security_group_ids = [data.aws_security_group.app.id]
}

module "app-lb" {
  source            = "../../modules/elb"
  service           = local.project.service
  env               = local.project.env
  instance_ids      = module.app.instance_ids
  instance_count    = module.app.instance_count
  subnets           = data.aws_subnets.public.ids
  target_group_name = lookup(var.lb, "target_group_name")
  vpc_id            = data.aws_vpc.common.id
  listener          = var.listener
  health_check      = var.health_check
  target_type       = "instance"
  security_groups   = [data.aws_security_group.alb.id]
}

module "ecs-app" {
  source                 = "../../modules/ecs"
  service                = local.project.service
  env                    = local.project.env
  vpc_id                 = data.aws_vpc.common.id
  subnets                = data.aws_subnets.public.ids
  security_group_id      = data.aws_security_group.app.id
  target_group_arn       = module.app-lb.target_group_arn # app-lbを流用
  container_port         = 80
  image                  = "nginx:latest"
  enable_execute_command = true
}

module "athena" {
  source      = "../../modules/athena"
  project     = local.project.service
  environment = local.project.env
  region      = local.project.region
}
