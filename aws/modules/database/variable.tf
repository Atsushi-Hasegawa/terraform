variable "project" {
  type = string
}
variable "environment" {
  type = string
}
variable "private_domain" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "access_logs_bucket" {
  type = string
}
variable "rds_port" {
  type        = number
  default     = 3306
  description = "RDS port number (e.g., 3306 for MySQL, 5432 for PostgreSQL)"
}

variable "db_readonly_user" {
  type        = string
  description = "The database user name for Databricks (read-only)"
  default     = "databricks_readonly"
}

variable "database_insights_mode" {
  type        = string
  description = "The mode for Performance Insights. Valid values are standard or advanced."
  default     = "advanced"
}

variable "ecs_security_group_id" {
  type        = string
  description = "The ID of the security group for ECS tasks"
  default     = null
}

variable "ec2_security_group_id" {
  type        = string
  description = "The ID of the security group for EC2 instances"
  default     = null
}

variable "lambda_security_group_id" {
  type        = string
  description = "The ID of the security group for Lambda functions"
  default     = null
}

variable "allowed_principal_arns" {
  type        = list(string)
  description = "Additional allowed principal ARNs for PrivateLink"
  default     = []
}

variable "database" {
  type = object({
    name           = string
    username       = string
    instance_class = string
  })
  sensitive = true
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "enable_databricks_federated" {
  type    = bool
  default = false
}
variable "rds_security_group_id" {
  type = string
}
variable "nlb_security_group_id" {
  type    = string
  default = null
}
variable "subnet_ids" {
  type = list(string)
}
variable "vpc_id" {
  type = string
}

variable "shared_account_ids" {
  type        = list(string)
  description = "List of AWS Account IDs to share the encrypted RDS snapshot with"
  default     = []
}
