# Remote state storage (S3) and state locking (DynamoDB).
#
# These two resources make the deployment manageable from GitHub Actions:
# the state lives in S3 (versioned, encrypted) and concurrent applies are
# serialised by the DynamoDB lock table.
#
# Bootstrap order (details in README.md):
#   1. The very first `terraform apply` runs against LOCAL state and creates
#      the bucket and the table below together with the rest of the stack.
#   2. Activate the commented-out `backend "s3"` block in provider.tf.
#   3. `terraform init -migrate-state` copies the local state into S3.
#   4. From then on every apply (including GitHub Actions) uses S3.

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "${var.project_name}-${var.environment}-terraform-state"
  force_destroy = true # course project: allow destroying the stack even with state objects inside

  tags = { Name = "${var.project_name}-${var.environment}-terraform-state" }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-${var.environment}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "${var.project_name}-${var.environment}-terraform-locks" }
}
