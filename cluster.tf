resource "aws_kms_key" "cluster" {
  description             = "KMS Key Fargate cluster"
  deletion_window_in_days = 7
  policy = jsonencode({
    Id = "Allow CloudWatch & SSM"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid = "Enable IAM User Permissions"
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.current_region}.amazonaws.com"
        }
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${local.current_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Sid = "Enable IAM User Permissions"
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Resource = "*"
      }
    ]
    Version = "2012-10-17"
    }
  )
}

resource "aws_kms_alias" "cluster" {
  name          = "alias/${local.resources_prefix}-fargate"
  target_key_id = aws_kms_key.cluster.arn
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "${local.resources_prefix}-cluster-logs"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cluster.arn
}

resource "aws_ecs_cluster" "main" {
  name = "${local.resources_prefix}-cluster"

  configuration {
    execute_command_configuration {
      # kms_key_id = aws_kms_key.cluster.arn
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.cluster.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
