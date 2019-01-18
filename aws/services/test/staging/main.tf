module "vpc-main" {
  source         = "../../../modules/network"
  service        = "project"
  env            = "staging"
  public_subnet  = "${lookup(var.network, "public_subnet")}"
  private_subnet = "${lookup(var.network, "private_subnet")}"
  vpc_cidr       = "${lookup(var.network, "vpc_cidr")}"
  public_az      = "${lookup(var.network, "public_az")}"
  private_az     = "${lookup(var.network, "private_az")}"
}

module "app" {
  source        = "../../../modules/ec2"
  service       = "project"
  env           = "staging"
  ami           = "${lookup(var.ec2,"ami")}"
  instance_type = "${lookup(var.ec2, "instance_type")}"
  count         = "${lookup(var.ec2,"count")}"
  subnet_id     = "${element(split(",",module.vpc-main.subnet_ids),1)}"
}

module "app-lb" {
  source            = "../../../modules/elb"
  service           = "project"
  env               = "staging"
  instance_ids      = "${join(",",module.app.instance_ids)}"
  count             = "${module.app.instance_count}"
  subnets           = "${module.vpc-main.subnet_ids}"
  target_group_name = "${lookup(var.lb, "target_group_name")}"
  vpc_id            = "${module.vpc-main.vpc_id}"
}

module "s3-cloudfront" {
  source                           = "../../../modules/s3"
  service                          = "project"
  env                              = "staging"
  bucket_name                      = "${lookup(var.storage, "name")}"
  bucket_acl                       = "${lookup(var.storage, "acl")}"
  cloudfront_origin_access_comment = "${lookup(var.storage, "cloudfront_comment")}"
}
