# ... (existing variables) ...
variable "deletion_protection" {
  description = "If true, the DB instance cannot be deleted"
  type        = bool
  default     = true
}

variable "delete_automated_backups" {
  description = "Whether to remove automated backups immediately after the DB instance is deleted"
  type        = bool
  default     = false # 削除後もバックアップを残す (レジリエンス重視)
}

variable "backup_retention_period" {
  description = "How many days to keep backups"
  type        = number
  default     = 35
}

# (Existing variables like vpc_id, subnet_ids, etc. are assumed to be present)
