mock_provider "aws" {}

run "backup_resilience_compliance" {
  command = plan

  module {
    source = "../../../aws/modules/backup"
  }

  variables {
    env                = "test"
    vault_name         = "resilience-vault"
    retention_days     = 30
    min_retention_days = 7
    changeable_for_days = 3
    resource_tags      = {
      BackupPolicy = "high-resilience"
    }
  }

  # 1. Vault Lock (不変性) の検証
  assert {
    condition     = aws_backup_vault_lock_configuration.this.min_retention_days == 7
    error_message = "Vault Lock minimum retention period is incorrect"
  }

  # 2. 自動選択 (DI) の検証
  assert {
    condition     = tolist(aws_backup_selection.this.selection_tag)[0].value == "high-resilience"
    error_message = "Backup selection tag is not correctly configured"
  }

  # 3. バックアッププランの検証 (tolist を使用)
  assert {
    condition     = tolist(aws_backup_plan.this.rule)[0].lifecycle[0].delete_after == 30
    error_message = "Backup retention lifecycle is incorrect"
  }
}
