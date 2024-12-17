# ##############################################################
# Service
# ##############################################################

resource "aws_cloudwatch_log_group" "jitsi_web" {
  name              = "${local.resources_prefix}-jitsi-web-logs"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cluster.arn
}

resource "aws_ecs_service" "jitsi_web" {

  depends_on = [
    aws_cloudwatch_log_group.jitsi_web
  ]

  name            = "${local.resources_prefix}-jitsi-web"
  cluster         = aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.jitsi_web.arn

  deployment_controller {
    type = "ECS"
  }

  desired_count                      = 1
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Jitsi web is Internet exposed, consequently its target group is connected to a public load balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.jitsi_web.arn
    container_name   = "web"
    container_port   = "443"
  }

  network_configuration {
    # ECS service on public subnet because no NAT gateway available (cost optimization)
    subnets         = module.vpc.public_subnets
    security_groups = [aws_security_group.jitsi_web.id]

    # Public IP not required - we will not use letsencrypt
    assign_public_ip = false
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

# IP target group for service tasks
resource "aws_lb_target_group" "jitsi_web" {
  name                 = "${local.resources_prefix}-jitsi-web-${substr(uuid(), 0, 4)}"
  port                 = "443"
  protocol             = "TLS"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = "60"
  slow_start           = "0"

  health_check {
    port     = "traffic-port"
    protocol = "HTTPS"
    path     = "/"
    matcher  = "200-299,300-399"
  }

  lifecycle {
    create_before_destroy = "true"
    ignore_changes = [
      name
    ]
  }
}

resource "aws_security_group" "jitsi_web" {

  name_prefix = "${local.resources_prefix}-jitsi-web-"
  description = "Security group of Jitsi Web service"
  vpc_id      = module.vpc.vpc_id

  tags = {
    "Name" = "${local.resources_prefix}-jitsi-web"
  }

  lifecycle {
    create_before_destroy = "true"
  }
}

# From ALB to ECS service
resource "aws_security_group_rule" "ingress_lb_to_jitsi_web" {

  description = "Incoming traffic from ALB to Jitsi web"
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "TCP"

  cidr_blocks       = ["0.0.0.0/0"] # Public Internet facing (Network load balancer)
  security_group_id = aws_security_group.jitsi_web.id
}

# Egress Internet rule
resource "aws_security_group_rule" "egress_jitsi_web" {

  description = "Outgoing traffic"
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.jitsi_web.id
}

# ##############################################################
# Task Definition
# ##############################################################

resource "aws_ecs_task_definition" "jitsi_web" {
  family                   = "${local.resources_prefix}-jitsi-web"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  # awslogs driver configuration redirect every stdout output to cloudwatch logs
  container_definitions = jsonencode(
    [
      {
        essential = true,
        image     = var.jitsi_images.web,
        name      = "web",
        secrets = [
          # TODO: see gen-passwords.sh
        ]
        environment = [
          {
            # https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker/#lets-encrypt-configuration
            name  = "ENABLE_LETSENCRYPT",
            value = "0",
          },
          {
            name  = "LETSENCRYPT_DOMAIN",
            value = var.domain_name,
          },
          {
            name  = "LETSENCRYPT_EMAIL",
            value = "root@${var.domain_name}",
          },
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
            containerPort = 443,
            hostPort      = 443,
            protocol      = "tcp"
          }
        ],
        logConfiguration = {
          logDriver = "awslogs",
          options = {
            awslogs-group         = "${aws_cloudwatch_log_group.jitsi_web.name}",
            awslogs-region        = local.current_region,
            awslogs-stream-prefix = "${local.resources_prefix}-jitsi-web-"
            mode                  = "non-blocking"
          }
        },
      },
  ])
  task_role_arn      = aws_iam_role.jitsi_web.arn
  execution_role_arn = aws_iam_role.task_exe.arn
}

resource "aws_iam_role" "jitsi_web" {

  name = "${local.resources_prefix}-jitsi-web-task-role"
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

resource "aws_iam_policy" "jitsi_web" {
  name = "${local.resources_prefix}-jitsi-web-task-policy"
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

resource "aws_iam_role_policy_attachment" "jitsi_web" {
  role       = aws_iam_role.jitsi_web.id
  policy_arn = aws_iam_policy.jitsi_web.arn
}
