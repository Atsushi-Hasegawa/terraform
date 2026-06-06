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

  # 1. IMDS v2 の必須化 (Credential protection)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  network_interfaces {
    associate_public_ip_address = false # セキュリティ向上のためパブリックIPを無効化
    security_groups             = [aws_security_group.worker-security-group.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance-profile.name
  }

  user_data = base64encode(local.worker-userdata)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Project     = "terraform-1"
      Environment = "staging"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
