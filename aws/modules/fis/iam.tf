resource "aws_iam_role" "fis" {
  name = format("%s%sFISRole", title(var.project), title(var.environment))
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "fis.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "fis_ecs" {
  statement {
    sid    = "FISECSActions"
    effect = "Allow"
    actions = [
      "ecs:ListTasks",
      "ecs:DescribeTasks",
      "ecs:StopTask"
    ]
    resources = [
      format("arn:aws:ecs:%s:%s:task/%s/*", local.region, local.account_id, split("/", var.cluster_arn)[1])
    ]
  }
}

data "aws_iam_policy_document" "fis_ec2" {
  statement {
    sid    = "FISEC2Actions"
    effect = "Allow"
    actions = [
      "ec2:RebootInstances",
      "ec2:StopInstances",
      "ec2:StartInstances",
      "ec2:TerminateInstances",
    ]
    # Restrict to instances with specific project/environment tags
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [var.environment]
    }
  }

  statement {
    sid    = "FISEC2Describe"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances"
    ]
    resources = ["*"] # Describe typically requires *
  }
}

data "aws_iam_policy_document" "fis_combined" {
  source_policy_documents = [
    data.aws_iam_policy_document.fis_ecs.json,
    data.aws_iam_policy_document.fis_ec2.json
  ]
}

resource "aws_iam_policy" "fis" {
  name   = format("%s%sFISPolicy", title(var.project), title(var.environment))
  policy = data.aws_iam_policy_document.fis_combined.json
}

resource "aws_iam_role_policy_attachment" "fis" {
  role       = aws_iam_role.fis.name
  policy_arn = aws_iam_policy.fis.arn
}
