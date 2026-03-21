resource "aws_kinesis_firehose_delivery_stream" "delivery_stream" {
  name        = format("%s-%s-firehose", var.project, var.environment)
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = aws_s3_bucket.data_bucket.arn
    prefix              = "events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"

    kms_key_arn = aws_kms_key.athena_key.arn

    buffering_size     = 128 // MB
    buffering_interval = 300 // Seconds

    compression_format = "UNCOMPRESSED" // Parquet is already compressed

    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {
            compression = "SNAPPY"
          }
        }
      }

      schema_configuration {
        database_name = aws_glue_catalog_database.database.name
        table_name    = aws_glue_catalog_table.table.name
        role_arn      = aws_iam_role.firehose_role.arn
        region        = var.region
      }
    }

    dynamic_partitioning_configuration {
      enabled = true
    }
  }
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.project}-${var.environment}-firehose"
  retention_in_days = var.retention_in_days
}
