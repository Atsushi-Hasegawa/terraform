variable "env" {
  description = "Environment name"
  type        = string
}

variable "vault_name" {
  description = "Name of the backup vault"
  type        = string
}

variable "retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 35
}

variable "min_retention_days" {
  description = "Minimum retention period for Vault Lock"
  type        = number
  default     = 7
}

variable "changeable_for_days" {
  description = "Cool-down period in days where the lock configuration can still be deleted or changed"
  type        = number
  default     = 3
}

variable "backup_schedule" {
  description = "Cron expression for backup schedule"
  type        = string
  default     = "cron(0 15 * * ? *)" # 毎日深夜0時（JST）
}

variable "resource_tags" {
  description = "Tags to identify resources to back up"
  type        = map(string)
  default     = {
    BackupPolicy = "high-resilience"
  }
}
