data "aws_region" "current" {}

locals {
  worker-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.master-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.master-cluster.certificate_authority.0.data}' '${aws_eks_cluster.master-cluster.name}'
USERDATA
}

resource "aws_launch_configuration" "launch" {
  associate_public_ip_address = true
  key_name                    = lookup(var.eks, "key_name")
  iam_instance_profile        = aws_iam_instance_profile.instance-profile.name
  image_id                    = data.aws_ami.eks-worker.id
  instance_type               = lookup(var.eks, "instance_type")
  name_prefix                 = aws_eks_cluster.master-cluster.name
  security_groups             = ["${aws_security_group.worker-security-group.id}"]
  user_data_base64            = base64encode(local.worker-userdata)

  lifecycle {
    create_before_destroy = true
  }
}
