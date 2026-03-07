resource "aws_kms_key" "rds" {
  description             = format("KMS key for RDS %s-%s", var.environment, var.database.name)
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.rds_kms_policy.json

  tags = {
    Name        = format("%s-%s-rds-key", var.environment, var.database.name)
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "rds_kms_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    actions = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid    = "Allow use of the key for RDS"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }

  # Allow external accounts to use the key (required for sharing encrypted snapshots)
  dynamic "statement" {
    for_each = length(var.shared_account_ids) > 0 ? [1] : []
    content {
      sid    = "Allow access for External Accounts"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = [for id in var.shared_account_ids : "arn:aws:iam::${id}:root"]
      }
    }
  }
}

resource "aws_kms_alias" "rds" {
  name          = format("alias/%s-%s-rds-key", var.environment, var.database.name)
  target_key_id = aws_kms_key.rds.key_id
}
