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
      format("arn:aws:ecs:%s:%s:task/*", local.region, local.account_id)
    ]
  }
}

data "aws_iam_policy_document" "fis_combined" {
  source_policy_documents = [
    data.aws_iam_policy_document.fis_ecs.json
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
