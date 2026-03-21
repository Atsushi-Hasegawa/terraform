output "firehose_delivery_stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.delivery_stream.arn
}

output "data_bucket_name" {
  value = aws_s3_bucket.data_bucket.bucket
}

output "glue_database_name" {
  value = aws_glue_catalog_database.database.name
}

output "glue_table_name" {
  value = aws_glue_catalog_table.table.name
}

output "athena_workgroup_name" {
  value = aws_athena_workgroup.default.name
}
