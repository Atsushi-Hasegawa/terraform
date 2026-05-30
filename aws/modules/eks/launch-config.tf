data "aws_region" "current" {}

locals {
  worker-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.master-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.master-cluster.certificate_authority.0.data}' '${aws_eks_cluster.master-cluster.name}'
USERDATA
}

resource "aws_launch_template" "launch" {
  name_prefix   = aws_eks_cluster.master-cluster.name
  image_id      = data.aws_ami.eks-worker.id
  instance_type = lookup(var.eks, "instance_type")
  key_name      = lookup(var.eks, "key_name")

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.worker-security-group.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance-profile.name
  }

  user_data = base64encode(local.worker-userdata)

  lifecycle {
    create_before_destroy = true
  }
}
