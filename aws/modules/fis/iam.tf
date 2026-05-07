# ... (existing iam code) ...

data "aws_iam_policy_document" "fis_ebs" {
  statement {
    sid    = "FISEBSActions"
    effect = "Allow"
    actions = [
      "ec2:PauseVolumeIO",
      "ec2:ResumeVolumeIO"
    ]
    resources = ["arn:aws:ec2:*:*:volume/*"]
  }
}

# (Add this to the combined policy document)
data "aws_iam_policy_document" "fis_combined" {
  source_policy_documents = [
    data.aws_iam_policy_document.fis_ecs.json,
    data.aws_iam_policy_document.fis_ec2.json,
    data.aws_iam_policy_document.fis_rds.json,
    data.aws_iam_policy_document.fis_ssm.json,
    data.aws_iam_policy_document.fis_network.json,
    data.aws_iam_policy_document.fis_control_plane.json,
    data.aws_iam_policy_document.fis_ebs.json # Added
  ]
}
