resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn             = aws_iam_role.vpc_flow_log_role.arn
  log_destination          = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.vpc-main.id
  max_aggregation_interval = 60

  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${tcp-flags} $${traffic-path} $${pkt-srcaddr} $${pkt-dstaddr} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${flow-direction}"

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
