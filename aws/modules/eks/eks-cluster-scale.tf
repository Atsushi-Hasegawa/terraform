data "aws_caller_identity" "current" {}

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.master-cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

resource "aws_autoscaling_group" "autoscale-group" {
  desired_capacity     = "${lookup(var.autoscale, "desired_capacity")}"
  launch_configuration = "${aws_launch_configuration.launch.id}"
  max_size             = "${lookup(var.autoscale, "max_size")}"
  min_size             = "${lookup(var.autoscale, "min_size")}"
  name                 = "${lookup(var.autoscale, "name")}"
  vpc_zone_identifier  = ["${var.subnets}"]

  tag {
    key                 = "Name"
    value               = "${aws_eks_cluster.master-cluster.name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${aws_eks_cluster.master-cluster.name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

locals {
  configmap = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.worker-role.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}
