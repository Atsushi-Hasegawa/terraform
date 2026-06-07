# 1. VPC Flow Logs 用の Athena テーブル定義 (Partition Projection)
resource "aws_glue_catalog_table" "vpc_flow_logs" {
  name          = "vpc_flow_logs"
  database_name = aws_glue_catalog_database.database.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "projection.enabled"  = "true"
    "projection.year.type"  = "integer"
    "projection.year.range" = "2024,2030"
    "projection.month.type" = "integer"
    "projection.month.range" = "1,12"
    "projection.month.digits" = "2"
    "projection.day.type"   = "integer"
    "projection.day.range"  = "1,31"
    "projection.day.digits" = "2"
    "projection.hour.type"  = "integer"
    "projection.hour.range" = "0,23"
    "projection.hour.digits" = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.data_bucket.bucket}/vpc-flow-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${var.region}/year=!{year}/month=!{month}/day=!{day}/hour=!{hour}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_bucket.bucket}/vpc-flow-logs/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "version"
      type = "int"
    }
    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "interface_id"
      type = "string"
    }
    columns {
      name = "srcaddr"
      type = "string"
    }
    columns {
      name = "dstaddr"
      type = "string"
    }
    columns {
      name = "srcport"
      type = "int"
    }
    columns {
      name = "dstport"
      type = "int"
    }
    columns {
      name = "protocol"
      type = "bigint"
    }
    columns {
      name = "packets"
      type = "bigint"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "start"
      type = "bigint"
    }
    columns {
      name = "end"
      type = "bigint"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "log_status"
      type = "string"
    }
  }
...
  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
}

# 2. コンテナ (ECS/Fargate) アプリケーションログ用テーブル
resource "aws_glue_catalog_table" "app_logs" {
  name          = "app_logs"
  database_name = aws_glue_catalog_database.database.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "projection.enabled"  = "true"
    "projection.year.type"  = "integer"
    "projection.year.range" = "2024,2030"
    "projection.month.type" = "integer"
    "projection.month.range" = "1,12"
    "projection.month.digits" = "2"
    "projection.day.type"   = "integer"
    "projection.day.range"  = "1,31"
    "projection.day.digits" = "2"
    "projection.hour.type"  = "integer"
    "projection.hour.range" = "0,23"
    "projection.hour.digits" = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.data_bucket.bucket}/app-logs/year=!{year}/month=!{month}/day=!{day}/hour=!{hour}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_bucket.bucket}/app-logs/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "timestamp"
      type = "string"
    }
    columns {
      name = "log_level"
      type = "string"
    }
    columns {
      name = "trace_id"
      type = "string"
    }
    columns {
      name = "message"
      type = "string"
    }
    columns {
      name = "container_name"
      type = "string"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
}

data "aws_caller_identity" "current" {}

