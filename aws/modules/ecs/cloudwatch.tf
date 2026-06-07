resource "aws_cloudwatch_log_group" "ecs_service_log" {
  name              = format("/aws/ecs/%s-%s", var.service, var.env)
  retention_in_days = var.log_retention_in_days

  tags = {
    Name        = format("/aws/ecs/%s-%s", var.service, var.env)
    Environment = var.env
  }
}

# アプリケーションログの Athena 連携用転送設定
resource "aws_cloudwatch_log_subscription_filter" "ecs_to_firehose" {
  name            = "ecs-to-firehose-filter"
  log_group_name  = aws_cloudwatch_log_group.ecs_service_log.name
  filter_pattern  = ""
  destination_arn = var.firehose_arn
  role_arn        = var.cw_logs_to_firehose_role_arn
}

resource "aws_cloudwatch_log_group" "firelens_log" {
  name              = format("/aws/ecs/%s-%s-firelens", var.service, var.env)
  retention_in_days = var.log_retention_in_days

  tags = {
    Name        = format("/aws/ecs/%s-%s-firelens", var.service, var.env)
    Environment = var.env
  }
}

resource "aws_cloudwatch_log_group" "ecs_exec_audit_log" {
  name              = format("/aws/ecs/%s-%s-exec-audit", var.service, var.env)
  retention_in_days = var.log_retention_in_days

  tags = {
    Name        = format("/aws/ecs/%s-%s-exec-audit", var.service, var.env)
    Environment = var.env
  }
}
