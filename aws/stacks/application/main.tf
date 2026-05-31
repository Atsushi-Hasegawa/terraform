module "app" {
  source             = "../../modules/ec2"
  service            = var.project.service
  env                = var.project.env
  ami                = var.ec2_config.ami
  instance_type      = var.ec2_config.instance_type
  num                = var.ec2_config.count
  subnet_id          = var.subnet_ids
  encrypted          = var.ec2_config.encrypted
  device_name        = var.ec2_config.device_name
  security_group_ids = [var.app_sg_id]
}

module "app-lb" {
  source            = "../../modules/elb"
  service           = var.project.service
  env               = var.project.env
  instance_ids      = module.app.instance_ids
  instance_count    = module.app.instance_count
  subnets           = var.subnet_ids
  target_group_name = var.lb_config.target_group_name
  vpc_id            = var.vpc_id
  listener          = { name = "lb", listener_port = 80, listener_protocol = "http", lb_port = 80, lb_protocol = "http" }
  health_check      = { healthy_threshold = 2, unhealthy_threshold = 2, timeout = 10, path = "HTTP:80/", interval = 60 }
  target_type       = "instance"
  security_groups   = [var.alb_sg_id]
}

