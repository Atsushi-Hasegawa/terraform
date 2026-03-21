resource "aws_glue_catalog_database" "database" {
  name = format("%s_%s_db", var.project, var.environment)
}

resource "aws_glue_catalog_table" "table" {
  name          = format("%s_%s_table", var.project, var.environment)
  database_name = aws_glue_catalog_database.database.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                    = "TRUE"
    "parquet.compression"       = "SNAPPY"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2024,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.day.digits"     = "2"
    "projection.hour.type"      = "integer"
    "projection.hour.range"     = "0,23"
    "projection.hour.digits"    = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.data_bucket.bucket}/events/year=!{year}/month=!{month}/day=!{day}/hour=!{hour}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_bucket.bucket}/events/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }

    columns {
      name = "user_id"
      type = "string"
    }

    columns {
      name = "event_type"
      type = "string"
    }

    columns {
      name = "payload"
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
