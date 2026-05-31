provider "aws" {
  region = local.project.region
}

# --- Dependency Injection via Data Sources (from common/foundation) ---
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

# --- Resource Creation via Stack ---
module "app_stack" {
  source     = "../../stacks/application"
  project    = local.project
  ec2_config = var.ec2
  lb_config  = var.lb
  
  # DI: ネットワーク情報をスタックに注入
  vpc_id     = data.aws_vpc.common.id
  subnet_ids = data.aws_subnets.public.ids
  app_sg_id  = data.aws_security_group.app.id
  alb_sg_id  = data.aws_security_group.alb.id
}
