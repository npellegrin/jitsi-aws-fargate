# ##############################################################
# Service
# ##############################################################

resource "aws_cloudwatch_log_group" "jitsi_jicofo" {
  name              = "${local.resources_prefix}-jitsi-jicofo-logs"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cluster.arn
}

resource "aws_ecs_service" "jitsi_jicofo" {

  depends_on = [
    aws_cloudwatch_log_group.jitsi_jicofo
  ]

  name            = "${local.resources_prefix}-jitsi-jicofo"
  cluster         = aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.jitsi_jicofo.arn

  deployment_controller {
    type = "ECS"
  }

  desired_count                      = 1
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    security_groups  = [aws_security_group.jitsi_jicofo.id]
    subnets          = var.deploy_in_private_subnets ? module.vpc.private_subnets : module.vpc.public_subnets
    assign_public_ip = !var.deploy_in_private_subnets
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
    base              = 0
  }

  enable_execute_command = true

  propagate_tags = "SERVICE"

  triggers = {
    redeployment = timestamp()
  }
}

resource "aws_security_group" "jitsi_jicofo" {

  name_prefix = "${local.resources_prefix}-jitsi-jicofo-"
  description = "Security group of Jitsi Web service"
  vpc_id      = module.vpc.vpc_id

  tags = {
    "Name" = "${local.resources_prefix}-jitsi-jicofo"
  }

  lifecycle {
    create_before_destroy = "true"
  }
}

# TODO: service discovery and internal DNS

# From Prosody to ECS service
resource "aws_security_group_rule" "ingress_jitsi_prosody_to_jitsi_jicofo" {

  description = "Incoming traffic from Jitsi Prosody to Jitsi Focus Component"
  type        = "ingress"
  from_port   = 8888
  to_port     = 8888
  protocol    = "TCP"

  source_security_group_id = aws_security_group.jitsi_prosody.id
  security_group_id        = aws_security_group.jitsi_jicofo.id
}

# Egress Internet rule
resource "aws_security_group_rule" "egress_jitsi_jicofo" {

  description = "Outgoing traffic"
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.jitsi_jicofo.id
}

# ##############################################################
# Task Definition
# ##############################################################

resource "aws_ecs_task_definition" "jitsi_jicofo" {
  family                   = "${local.resources_prefix}-jitsi-jicofo"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 1024

  # awslogs driver configuration redirect every stdout output to cloudwatch logs
  container_definitions = jsonencode(
    [
      {
        essential = true,
        image     = var.jitsi_images.jicofo,
        name      = "jicofo",
        secrets = [
          {
            name      = "JICOFO_AUTH_PASSWORD"
            valueFrom = aws_ssm_parameter.jitsi_passwords["JICOFO_AUTH_PASSWORD"].arn
          }
        ]
        environment = [
          # TODO: see available params in docker-compose.yaml
          {
            name  = "PUBLIC_URL",
            value = "https://${var.domain_name}",
          },
          {
            name  = "ENABLE_RECORDING",
            value = "0",
          },
        ],
        portMappings = [
          {
            containerPort = 8888,
            hostPort      = 8888,
            protocol      = "tcp"
          }
        ],
        logConfiguration = {
          logDriver = "awslogs",
          options = {
            awslogs-group         = "${aws_cloudwatch_log_group.jitsi_jicofo.name}",
            awslogs-region        = local.current_region,
            awslogs-stream-prefix = "${local.resources_prefix}-jitsi-jicofo-"
            mode                  = "non-blocking"
          }
        },
      },
  ])
  task_role_arn      = aws_iam_role.jitsi_jicofo.arn
  execution_role_arn = aws_iam_role.task_exe.arn
}

resource "aws_iam_role" "jitsi_jicofo" {

  name = "${local.resources_prefix}-jitsi-jicofo-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
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

resource "aws_iam_policy" "jitsi_jicofo" {
  name = "${local.resources_prefix}-jitsi-jicofo-task-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWorkerToCloudwatch"
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowWorkersToUseeCMK",
        Effect = "Allow",
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ],
        Resource = [
          aws_kms_key.cluster.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jitsi_jicofo" {
  role       = aws_iam_role.jitsi_jicofo.id
  policy_arn = aws_iam_policy.jitsi_jicofo.arn
}
