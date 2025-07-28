
run "s3_bucket_creation" {
  command = plan

  variables {
    bucket_name = "test-bucket"
    bucket_acl = "private"
    cloudfront_origin_access_comment = "test-comment"
  }
}
