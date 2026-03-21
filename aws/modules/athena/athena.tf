resource "aws_athena_workgroup" "default" {
  name = format("%s-%s-group", var.project, var.environment)

  configuration {
    enforce_workgroup_configuration    = true
    bytes_scanned_cutoff_per_query     = 1073741824 // 1GB
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results_bucket.bucket}/results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.athena_key.arn
      }
    }
  }

  description = "Workgroup for ${var.project} ${var.environment}"
}