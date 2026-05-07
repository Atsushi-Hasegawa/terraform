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
  instance_count    = module.app.instance_count
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
  instance_count    = 0
  subnets           = module.vpc-main.subnet_ids
  target_group_name = "ecs-staging-tg"
  vpc_id            = module.vpc-main.vpc_id
  listener          = var.listener
  health_check      = var.health_check
  target_type       = "ip"
  security_groups   = [module.vpc-main.alb_sg_id]
}

module "ecs-app" {
  source                 = "../../../modules/ecs"
  service                = "project"
  env                    = "staging"
  vpc_id                 = module.vpc-main.vpc_id
  subnets                = module.vpc-main.subnet_ids
  security_group_id      = module.vpc-main.ecs_sg_id
  target_group_arn       = module.ecs-lb.target_group_arn
  container_port         = 80
  image                  = "nginx:latest"
  enable_execute_command = true
}

module "athena" {
  source      = "../../../modules/athena"
  project     = "project"
  environment = "staging"
  region      = var.region
}

module "fis" {
  source      = "../../../modules/fis"
  project     = "project"
  environment = "staging"
  cluster_arn = module.ecs-app.cluster_arn
  
  fis = {
    # 1台だけECSタスクを落とすSPOF試験
    ecs = [{
      cluster_name   = split("/", module.ecs-app.cluster_arn)[1]
      service_name   = module.ecs-app.service_name
      selection_mode = "COUNT(1)"
    }]

    # EC2の停止試験
    ec2 = [{
      instance_ids   = module.app.instance_ids
      selection_mode = "COUNT(1)"
    }]

    # RDS試験（必要に応じて追加）
    rds = []

    # ネットワーク不安定化試験 (Packet Loss 5%, Jitter 10ms)
    network_advanced = [{
      instance_ids   = module.app.instance_ids
      selection_mode = "ALL"
      duration       = "PT5M"
      loss           = "5%"
      jitter         = "10ms"
      dns_fault      = "delay"
    }]

    # API Error Injection (ECSのDescribeTasksを50%の確率でエラーにする)
    api_fault = [{
      service        = "ecs"
      operation_name = "DescribeTasks"
      error_code     = "Throttling"
      percentage     = 50
      duration       = "PT10M"
    }]

    # 観測障害 (CloudWatchへの通信遮断)
    observability_disruption = [{
      instance_ids   = module.app.instance_ids
      selection_mode = "ALL"
      duration       = "PT5M"
      target_service = "cloudwatch"
    }]

    # 連鎖障害シナリオ
    chained_scenarios = [{
      name         = "cascading-failure"
      instance_ids = module.app.instance_ids
      duration     = "PT15M"
    }]
  }
}
