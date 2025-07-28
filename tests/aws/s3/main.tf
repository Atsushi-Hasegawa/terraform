module "s3" {
  source = "../../../aws/modules/s3"

  bucket_name = var.bucket_name
  bucket_acl = var.bucket_acl
  cloudfront_origin_access_comment = var.cloudfront_origin_access_comment
}

variable "bucket_name" {}
variable "bucket_acl" {}
variable "cloudfront_origin_access_comment" {}
