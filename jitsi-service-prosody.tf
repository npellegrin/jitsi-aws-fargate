# ##############################################################
# Service
# ##############################################################

resource "aws_cloudwatch_log_group" "jitsi_prosody" {
  name              = "${local.resources_prefix}-jitsi-prosody-logs"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cluster.arn
}

resource "aws_ecs_service" "jitsi_prosody" {

  depends_on = [
    aws_cloudwatch_log_group.jitsi_prosody
  ]

  name            = "${local.resources_prefix}-jitsi-prosody"
  cluster         = aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.jitsi_prosody.arn

  deployment_controller {
    type = "ECS"
  }

  desired_count                      = 1
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    security_groups  = [aws_security_group.jitsi_prosody.id]
    subnets          = var.deploy_in_private_subnets ? module.vpc.private_subnets : module.vpc.public_subnets
    assign_public_ip = !var.deploy_in_private_subnets
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
    base              = 0
  }


  service_registries {
    registry_arn = aws_service_discovery_service.jitsi_prosody.arn
  }

  enable_execute_command = true

  propagate_tags = "SERVICE"

  triggers = {
    redeployment = timestamp()
  }
}

resource "aws_security_group" "jitsi_prosody" {

  name_prefix = "${local.resources_prefix}-jitsi-prosody-"
  description = "Security group of Jitsi Web service"
  vpc_id      = module.vpc.vpc_id

  tags = {
    "Name" = "${local.resources_prefix}-jitsi-prosody"
  }

  lifecycle {
    create_before_destroy = "true"
  }
}

# TODO: service discovery and internal DNS

# From Web to Prosody
resource "aws_security_group_rule" "ingress_jitsi_web_to_jitsi_prosody_5222" {

  description = "Incoming traffic from Jitsi Web to Jitsi Prosody"
  type        = "ingress"
  from_port   = 5222
  to_port     = 5222
  protocol    = "TCP"

  source_security_group_id = aws_security_group.jitsi_web.id
  security_group_id        = aws_security_group.jitsi_prosody.id
}
resource "aws_security_group_rule" "ingress_jitsi_web_to_jitsi_prosody_5347" {

  description = "Incoming traffic from Jitsi Web to Jitsi Prosody"
  type        = "ingress"
  from_port   = 5347
  to_port     = 5347
  protocol    = "TCP"

  source_security_group_id = aws_security_group.jitsi_web.id
  security_group_id        = aws_security_group.jitsi_prosody.id
}
resource "aws_security_group_rule" "ingress_jitsi_web_to_jitsi_prosody_5280" {

  description = "Incoming traffic from Jitsi Web to Jitsi Prosody"
  type        = "ingress"
  from_port   = 5280
  to_port     = 5280
  protocol    = "TCP"

  source_security_group_id = aws_security_group.jitsi_web.id
  security_group_id        = aws_security_group.jitsi_prosody.id
}

# From JVB to Prosody
resource "aws_security_group_rule" "ingress_jitsi_jvb_to_jitsi_prosody_5222" {

  description = "Incoming traffic from Jitsi Web to Jitsi Prosody"
  type        = "ingress"
  from_port   = 5222
  to_port     = 5222
  protocol    = "TCP"

  source_security_group_id = aws_security_group.jitsi_jvb.id
  security_group_id        = aws_security_group.jitsi_prosody.id
}

# From Jicofo to Prosody
resource "aws_security_group_rule" "ingress_jitsi_jicofo_to_jitsi_prosody_5222" {

  description = "Incoming traffic from Jitsi Web to Jitsi Prosody"
  type        = "ingress"
  from_port   = 5222
  to_port     = 5222
  protocol    = "TCP"

  source_security_group_id = aws_security_group.jitsi_jicofo.id
  security_group_id        = aws_security_group.jitsi_prosody.id
}

# Egress Internet rule
resource "aws_security_group_rule" "egress_jitsi_prosody" {

  description = "Outgoing traffic"
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.jitsi_prosody.id
}

# ##############################################################
# Task Definition
# ##############################################################

resource "aws_ecs_task_definition" "jitsi_prosody" {
  family                   = "${local.resources_prefix}-jitsi-prosody"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 1024

  # awslogs driver configuration redirect every stdout output to cloudwatch logs
  container_definitions = jsonencode(
    [
      {
        essential = true,
        image     = var.jitsi_images.prosody,
        name      = "prosody",
        secrets = [
          for secret_key in toset([
            "JIBRI_RECORDER_PASSWORD",
            "JIBRI_XMPP_PASSWORD",
            "JICOFO_AUTH_PASSWORD",
            "JIGASI_XMPP_PASSWORD",
            "JVB_AUTH_PASSWORD",
          ]) :
          {
            name      = secret_key
            valueFrom = aws_ssm_parameter.jitsi_passwords[secret_key].arn
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
            containerPort = 5222,
            hostPort      = 5222,
            protocol      = "tcp"
          },
          {
            containerPort = 5347,
            hostPort      = 5347,
            protocol      = "tcp"
          },
          {
            containerPort = 5280,
            hostPort      = 5280,
            protocol      = "tcp"
          }
        ],
        logConfiguration = {
          logDriver = "awslogs",
          options = {
            awslogs-group         = "${aws_cloudwatch_log_group.jitsi_prosody.name}",
            awslogs-region        = local.current_region,
            awslogs-stream-prefix = "${local.resources_prefix}-jitsi-prosody-"
            mode                  = "non-blocking"
          }
        },
      },
  ])
  task_role_arn      = aws_iam_role.jitsi_prosody.arn
  execution_role_arn = aws_iam_role.task_exe.arn
}

resource "aws_iam_role" "jitsi_prosody" {

  name = "${local.resources_prefix}-jitsi-prosody-task-role"
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

resource "aws_iam_policy" "jitsi_prosody" {
  name = "${local.resources_prefix}-jitsi-prosody-task-policy"
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

resource "aws_iam_role_policy_attachment" "jitsi_prosody" {
  role       = aws_iam_role.jitsi_prosody.id
  policy_arn = aws_iam_policy.jitsi_prosody.arn
}
