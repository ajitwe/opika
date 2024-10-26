resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    "compliance"               = "nil"
    "data-category"            = "business:internal"
    "data-classification-tier" = "3"
  }

}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
    # mfa_delete = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "main_encryption" {
  bucket = aws_s3_bucket.main.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "main_iac" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket     = aws_s3_bucket.main.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.main.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_logging" "this" {

  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.main.id
  target_prefix = "self-log"

}


data "aws_iam_policy_document" "deny_insecure_transport" {

  statement {
    sid    = "denyInsecureTransport"
    effect = "Deny"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false"
      ]
    }
  }
}

data "aws_iam_policy_document" "require_latest_tls" {

  statement {
    sid    = "denyOutdatedTLS"
    effect = "Deny"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values = [
        "1.2"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {

  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.combined.json

  depends_on = [
    aws_s3_bucket_public_access_block.main_iac
  ]
}

data "aws_iam_policy_document" "combined" {

  source_policy_documents = compact([
    data.aws_iam_policy_document.require_latest_tls.json,
    data.aws_iam_policy_document.deny_insecure_transport.json

  ])
}
