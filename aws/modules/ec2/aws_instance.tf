resource "aws_instance" "app" {
  count         = var.num
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id[count.index]
  
  # Ensure no public IP is associated
  associate_public_ip_address = false

  ebs_block_device {
    encrypted   = var.encrypted
    device_name = var.device_name
  }

  vpc_security_group_ids = var.security_group_ids

  tags = {
    Name = "${format("web%02d", count.index + 1)}"
  }
}

# aws_eip.app is removed as we access via ALB only
