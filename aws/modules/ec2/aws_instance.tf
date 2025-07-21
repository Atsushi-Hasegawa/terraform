resource "aws_instance" "app" {
  count         = var.num
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id[count.index]
  ebs_block_device {
    encrypted   = var.encrypted
    device_name = var.device_name
  }

  tags = {
    Name = "${format("web%02d", count.index + 1)}"
  }
}

resource "aws_eip" "app" {
  count    = length(aws_instance.app)
  instance = element(aws_instance.app.*.id, count.index)
}
