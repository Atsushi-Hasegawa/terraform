module "vpc-main" {
  source             = "../../../modules/network"
  service            = "project"
  env                = "staging"
  vpc_cidr           = "${var.vpc}"
  subnets            = "${var.subnets}"
  availability_zones = "${var.availability_zones}"
}

module "app" {
  source        = "../../../modules/ec2"
  service       = "project"
  env           = "staging"
  ami           = "${lookup(var.ec2,"ami")}"
  instance_type = "${lookup(var.ec2, "instance_type")}"
  count         = "${lookup(var.ec2,"count")}"
  subnet_id     = "${module.vpc-main.subnet_ids}"
}

module "app-lb" {
  source            = "../../../modules/elb"
  service           = "project"
  env               = "staging"
  instance_ids      = "${module.app.instance_ids}"
  count             = "${module.app.instance_count}"
  subnets           = "${module.vpc-main.subnet_ids}"
  target_group_name = "${lookup(var.lb, "target_group_name")}"
  vpc_id            = "${module.vpc-main.vpc_id}"
  listener          = "${var.listener}"
  health_check      = "${var.health_check}"
}

module "s3-cloudfront" {
  source                           = "../../../modules/s3"
  service                          = "project"
  env                              = "staging"
  bucket_name                      = "${lookup(var.storage, "name")}"
  bucket_acl                       = "${lookup(var.storage, "acl")}"
  cloudfront_origin_access_comment = "${lookup(var.storage, "cloudfront_comment")}"
}

module "eks" {
  source                       = "../../../modules/eks"
  service                      = "project"
  env                          = "staging"
  subnets                      = "${module.vpc-main.subnet_ids}"
  master-security              = "${var.master-security}"
  master-security-rule         = "${var.master-security-rule}"
  master-role                  = "${var.master-role}"
  worker-role                  = "${var.worker-role}"
  vpc                          = "${module.vpc-main.vpc_id}"
  worker-security              = "${var.worker-security}"
  worker-security-rule         = "${var.worker-security-rule}"
  worker-egress-security-rule  = "${var.worker-egress-security-rule}"
  worker-ingress-security-rule = "${var.worker-ingress-security-rule}"
  autoscale                    = "${var.autoscale}"
  eks                          = "${var.eks}"
}
