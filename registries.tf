#
# Mirror of Docker registries to prevent docker.io throttling and removes the need of a NAT Gateway
# /!\ You must push corresponding images here once infrastructure deployed
#

resource "aws_kms_key" "registry" {
  description             = "KMS Key for private registries"
  deletion_window_in_days = 7
  policy = jsonencode({
    Id = "Default Permissions"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      }
    ]
    Version = "2012-10-17"
    }
  )
}

resource "aws_kms_alias" "registry" {
  name          = "alias/${local.resources_prefix}-registry"
  target_key_id = aws_kms_key.registry.arn
}

resource "aws_ecr_repository" "jitsi_jicofo" {
  name                 = "${local.resources_prefix}-mirror/jitsi/jicofo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.registry.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "jitsi_jvb" {
  name                 = "${local.resources_prefix}-mirror/jitsi/jvb"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.registry.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "jitsi_prosody" {
  name                 = "${local.resources_prefix}-mirror/jitsi/prosody"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.registry.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "jitsi_web" {
  name                 = "${local.resources_prefix}-mirror/jitsi/web"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.registry.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}
