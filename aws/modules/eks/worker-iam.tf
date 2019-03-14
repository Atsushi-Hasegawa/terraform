resource "aws_iam_role" "worker-role" {
  name               = "${lookup(var.worker-role, "name")}"
  assume_role_policy = "${file("${path.module}/config/worker-policy.json.tpl")}"
}

resource "aws_iam_role_policy_attachment" "eks-worker-node-policy" {
  role       = "${aws_iam_role.worker-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks-cni-policy" {
  role       = "${aws_iam_role.worker-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks-container-registry-readonly" {
  role       = "${aws_iam_role.worker-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "instance-profile" {
  name = "${lookup(var.eks, "name")}"
  role = "${aws_iam_role.worker-role.name}"
}
