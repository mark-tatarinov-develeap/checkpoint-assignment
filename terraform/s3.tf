resource "aws_s3_bucket" "messages" {
  bucket = "${var.project_name}-messages"

  tags = {
    Project = var.project_name
  }
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