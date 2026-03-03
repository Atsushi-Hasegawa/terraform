# MySQL ユーザーと権限設定 (手動実行が必要)
# SQL Example:
# CREATE USER 'databricks_readonly'@'10.x.x.x/x' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
# GRANT SELECT ON `db_name`.* TO 'databricks_readonly'@'10.x.x.x/x';

# Databricks 側の IAM ロールにアタッチするためのポリシー
resource "aws_iam_policy" "databricks_rds_connect" {
  name        = format("%s-%s-databricks-rds-connect", var.environment, var.database.name)
  description = "IAM Policy to allow Databricks to connect to RDS via IAM Authentication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "rds-db:connect"
        Resource = [
          format("arn:aws:rds-db:%s:%s:dbuser:%s/%s",
            local.region,
            local.account_id,
            aws_rds_cluster.base.cluster_resource_id,
            var.db_readonly_user
          )
        ]
      }
    ]
  })
}
