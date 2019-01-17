variable bucket_name {}
variable bucket_acl {}
variable cloudfront_origin_access_comment {}

variable policy_file {
  default = "policy.json.tpl"
}

variable env {}
variable service {}

resource "aws_s3_bucket" "bucket" {
  bucket        = "${var.bucket_name}"
  acl           = "${var.bucket_acl}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = "${aws_s3_bucket.bucket.id}"
  policy = "${data.aws_iam_policy_document.s3_site_policy.json}"
}

data "aws_iam_policy_document" "s3_site_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.cloudfront_origin_access.iam_arn}"]
    }
  }
}
