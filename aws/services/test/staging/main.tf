/*
module "app" {
  source = "../../../modules/ec2"
  service = "project"
  env = "staging"
  ami = "${lookup(var.ec2,"ami")}"
  instance_type = "${lookup(var.ec2, "instance_type")}"
  count = "${lookup(var.ec2,"count")}"
}

module "vpc-main" {
  source = "../../../modules/network"
  service = "project"
  env = "staging"
  public_subnet_a = "${lookup(var.network, "public_a")}"
  vpc_cidr = "${lookup(var.network, "vpc_cidr")}"
  private_subnet_c = "${lookup(var.network, "private_c")}"
}

module "app-elb" {
  source = "../../../modules/elb"
  service = "project"
  env = "staging"
  instance_ids = "${join(",",module.app.instance_ids)}"
  availability_zones = "${join(",",var.availability_zones)}"
}
*/
module "s3-cloudfront" {
  source                           = "../../../modules/s3"
  service                          = "project"
  env                              = "staging"
  bucket_name                      = "${lookup(var.storage, "name")}"
  bucket_acl                       = "${lookup(var.storage, "acl")}"
  cloudfront_origin_access_comment = "${lookup(var.storage, "cloudfront_comment")}"
}
