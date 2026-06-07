resource "aws_flow_log" "vpc_flow_log" {
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.vpc-main.id
  max_aggregation_interval = 60

  # S3への直接出力 (Athena高速化・コスト最適化のため)
  log_destination_type = "s3"
  log_destination      = "arn:aws:s3:::${var.project}-${var.env}-logs/vpc-flow-logs/"

  # 注: VPC Flow Logs は出力先 S3 バケットのデフォルト暗号化設定に従います。
  # ログバケット側で KMS (CMK) を有効にすることで、このログも自動的に KMS で暗号化されます。

  # Hive形式のパーティション投影に対応した出力設定
  destination_options {
    file_format                = "parquet" # Athenaでスキャン量を減らせる Parquet を指定
    hive_compatible_partitions = true      # year=YYYY/... 形式で出力
    per_hour_partition         = true      # 1時間ごとに分割 (調査の精度向上)
  }

  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${tcp-flags} $${traffic-path} $${pkt-srcaddr} $${pkt-dstaddr} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${flow-direction}"

  tags = {
    Name        = format("%s-vpc-flow-log", var.env)
    Environment = var.env
    Project     = var.project
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
