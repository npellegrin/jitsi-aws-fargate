###### TASK EXECUTION ROLE ###### Identical for all tasks #########

resource "aws_iam_role" "task_exe" {
  name = "${local.resources_prefix}-taskexec-role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole",
          Principal = {
            Service = [
              "ecs-tasks.amazonaws.com"
            ]
          },
          Effect = "Allow"
        }
      ]
  })
}

resource "aws_iam_policy" "task_exe" {
  name = "${local.resources_prefix}-taskexec-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ssm:GetParameters"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt*",
          "kms:Describe*"
        ],
        Resource = [
          aws_kms_key.cluster.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_exe" {
  role       = aws_iam_role.task_exe.id
  policy_arn = aws_iam_policy.task_exe.arn
}
