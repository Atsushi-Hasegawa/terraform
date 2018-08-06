module "app" {
  source = "../../../modules/ec2"
  service = "web%02d"
  env = "test"
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  count = "${var.count}"
}

module "vpc-main" {
  source = "../../../modules/network"
  service = "test"
  env = "test"
  public_subnet_a = "${lookup(var.subnet, "public_a")}"
  vpc_cidr = "${var.vpc_cidr}"
  private_subnet_c = "${lookup(var.subnet, "private_c")}"
}
