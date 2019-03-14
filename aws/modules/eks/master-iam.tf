resource "aws_iam_role" "master-role" {
  name               = "${lookup(var.master-role, "name")}"
  assume_role_policy = "${file("${path.module}/config/master-policy.json.tpl")}"
}

resource "aws_iam_role_policy_attachment" "eks-cluster-policy" {
  role       = "${aws_iam_role.master-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks-service-policy" {
  role       = "${aws_iam_role.master-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}
