resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = {
    Project     = "terraform-1"
    Environment = "staging"
  }
}

resource "aws_eks_cluster" "master-cluster" {
  name     = lookup(var.eks, "name")
  role_arn = aws_iam_role.master-role.arn

  # 1. ネットワーク境界の防御 (CRITICAL対策)
  vpc_config {
    security_group_ids      = [aws_security_group.master-security-group.id]
    subnet_ids              = var.subnets
    endpoint_public_access  = false # パブリックアクセスを完全に遮断
    endpoint_private_access = true
  }

  # 2. シークレットの保護 (HIGH対策)
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  tags = {
    Project     = "terraform-1"
    Environment = "staging"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-policy,
    aws_iam_role_policy_attachment.eks-service-policy,
  ]
}

locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.master-cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.master-cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws-iam-authenticator # updated from heptio
      args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.master-cluster.name}"
KUBECONFIG
}
