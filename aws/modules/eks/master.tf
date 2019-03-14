resource "aws_eks_cluster" "master-cluster" {
  name     = "${lookup(var.eks, "name")}"
  role_arn = "${aws_iam_role.master-role.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.master-security-group.id}"]
    subnet_ids         = ["${var.subnets}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks-cluster-policy",
    "aws_iam_role_policy_attachment.eks-service-policy",
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
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.master-cluster.name}"
KUBECONFIG
}
