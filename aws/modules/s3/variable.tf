variable "bucket_name" {}
variable "bucket_acl" {}
variable "env" {}

# 高レジリエンス設定フラグ
variable "enable_versioning" {
  description = "Enable versioning to allow recovery from accidental deletes/overwrites"
  type        = bool
  default     = true
}

variable "enable_object_lock" {
  description = "Enable Object Lock for Immutable backups"
  type        = bool
  default     = false
}

variable "retention_days" {
  description = "Object Lock retention period in days"
  type        = number
  default     = 7
}

variable "force_destroy" {
  description = "Allow the bucket to be deleted even if it contains objects (Dangerous for backups!)"
  type        = bool
  default     = false
}
variable "web_acl_id" { default = null }
