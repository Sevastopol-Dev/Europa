resource "aws_kms_key" "honeybucket_key" {
  description             = "Project Europa Deception KMS Key for Epoch ${var.epoch_id}"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true
}


# Organization-level Security Control Policy (SCP) baseline guardrail
resource "aws_s3_bucket" "canary_honeybucket" {
  bucket = var.quarantine_honeybucket

  tags = {
    Environment = "DeceptionTrap"
    Epoch       = var.epoch_id
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_s3_bucket_versioning" "honeybucket_versioning" {
  bucket = aws_s3_bucket.canary_honeybucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "honeybucket_encryption" {
  bucket = aws_s3_bucket.canary_honeybucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.honeybucket_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket                  = aws_s3_bucket.canary_honeybucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Ephemeral JIT Role driven by Identity Guardian Contract
resource "aws_iam_role" "europa_jti_role" {
  name = "europa-jti-pipeline-role-${var.epoch_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Epoch = var.epoch_id
    Type  = "EphemeralJIT"
  }
}

# Attach the Python-generated dynamic policy to the role
resource "aws_iam_role_policy" "dynamic_jit_attachment" {
  name   = "europa-dynamic-jit-policy"
  role   = aws_iam_role.europa_jti_role.id
  policy = jsonencode(var.ephemeral_pipeline_policy)
}

