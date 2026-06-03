# 1. Backup Vault
resource "aws_backup_vault" "this" {
  name = var.vault_name
  tags = {
    Environment = var.env
    Name        = var.vault_name
  }
}

# 2. Backup Vault Lock (Immutability)
# これにより、指定期間内は管理者でもバックアップを削除できなくなります
resource "aws_backup_vault_lock_configuration" "this" {
  backup_vault_name   = aws_backup_vault.this.name
  changeable_for_days = var.changeable_for_days
  min_retention_days  = var.min_retention_days
}

# 3. Backup Plan
resource "aws_backup_plan" "this" {
  name = "${var.vault_name}-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.retention_days
    }
  }
}

# 4. IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  name = "${var.vault_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_standard" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "restores_standard" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup.name
}

# 5. Resource Selection
# タグに基づいて自動的にバックアップ対象を選択
resource "aws_backup_selection" "this" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.vault_name}-selection"
  plan_id      = aws_backup_plan.this.id

  dynamic "selection_tag" {
    for_each = var.resource_tags
    content {
      type  = "STRINGEQUALS"
      key   = selection_tag.key
      value = selection_tag.value
    }
  }
}
