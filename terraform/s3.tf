resource "aws_s3_bucket" "messages" {
  bucket = "${var.project_name}-messages"

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "messages" {
  bucket = aws_s3_bucket.messages.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Default private ACL
resource "aws_s3_bucket_ownership_controls" "messages" {
  bucket = aws_s3_bucket.messages.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "messages" {
  bucket = aws_s3_bucket.messages.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.messages]
}

# SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "messages" {
  bucket = aws_s3_bucket.messages.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}