resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc-main.id

  tags = {
    Name        = format("%s-vpc-flow-log", var.env)
    Environment = var.env
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name              = format("/aws/vpc-flow-log/%s-vpc", var.env)
  retention_in_days = 365

  tags = {
    Name        = format("%s-vpc-flow-log-group", var.env)
    Environment = var.env
  }
}
