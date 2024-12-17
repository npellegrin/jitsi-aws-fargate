# ##############################################################
# Service
# ##############################################################

resource "aws_cloudwatch_log_group" "jitsi_jvb" {
  name              = "${local.resources_prefix}-jitsi-jvb-logs"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cluster.arn
}

resource "aws_ecs_service" "jitsi_jvb" {

  depends_on = [
    aws_cloudwatch_log_group.jitsi_jvb
  ]

  name            = "${local.resources_prefix}-jitsi-jvb"
  cluster         = aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.jitsi_jvb.arn

  deployment_controller {
    type = "ECS"
  }

  desired_count                      = 1
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Jitsi Video Bridge is Internet exposed, consequently its target group is connected to a public load balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.jitsi_jvb.arn
    container_name   = "jvb"
    container_port   = "10000"
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.jitsi_jvb_fallback.arn
    container_name   = "jvb"
    container_port   = "4443"
  }

  network_configuration {
    security_groups  = [aws_security_group.jitsi_jvb.id]
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

# IP target group for service tasks
resource "aws_lb_target_group" "jitsi_jvb" {
  name                 = "${local.resources_prefix}-jitsi-jvb-${substr(uuid(), 0, 4)}"
  port                 = "10000"
  protocol             = "UDP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = "60"
  slow_start           = "0"

  health_check {
    port     = "8080"
    protocol = "HTTP"
    path     = "/about/health"
    matcher  = "200"
  }

  lifecycle {
    create_before_destroy = "true"
    ignore_changes = [
      name
    ]
  }
}
resource "aws_lb_target_group" "jitsi_jvb_fallback" {
  name                 = "${local.resources_prefix}-jitsi-jvb-${substr(uuid(), 0, 4)}"
  port                 = "4443"
  protocol             = "TCP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = "60"
  slow_start           = "0"

  health_check {
    port     = "8080"
    protocol = "HTTP"
    path     = "/about/health"
    matcher  = "200"
  }

  lifecycle {
    create_before_destroy = "true"
    ignore_changes = [
      name
    ]
  }
}

resource "aws_security_group" "jitsi_jvb" {

  name_prefix = "${local.resources_prefix}-jitsi-jvb-"
  description = "Security group of Jitsi Web service"
  vpc_id      = module.vpc.vpc_id

  tags = {
    "Name" = "${local.resources_prefix}-jitsi-jvb"
  }

  lifecycle {
    create_before_destroy = "true"
  }
}

# From ALB to ECS service
resource "aws_security_group_rule" "ingress_lb_to_jitsi_jvb" {

  description = "Incoming traffic from ALB to Jitsi Video Bridge"
  type        = "ingress"
  from_port   = 10000
  to_port     = 10000
  protocol    = "UDP"

  cidr_blocks       = ["0.0.0.0/0"] # Public Internet facing (Network load balancer)
  security_group_id = aws_security_group.jitsi_jvb.id
}

resource "aws_security_group_rule" "ingress_lb_to_jitsi_jvb_fallback" {

  description = "Incoming traffic from ALB to Jitsi Video Bridge (fallback)"
  type        = "ingress"
  from_port   = 4443
  to_port     = 4443
  protocol    = "TCP"

  cidr_blocks       = ["0.0.0.0/0"] # Public Internet facing (Network load balancer)
  security_group_id = aws_security_group.jitsi_jvb.id
}

# From Prosody to ECS service
resource "aws_security_group_rule" "ingress_jitsi_prosody_to_jitsi_jvb" {

  description = "Incoming traffic from Jitsi Prosody to Jitsi Video Bridge"
  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "TCP"

  source_security_group_id = aws_security_group.jitsi_prosody.id
  security_group_id        = aws_security_group.jitsi_jvb.id
}

# Allow health checks (from entire VPC)
resource "aws_security_group_rule" "ingress_health_check_to_jitsi_jvb" {

  description = "Incoming traffic from VPC to Jitsi Video Bridge for Health Check"
  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "TCP"

  cidr_blocks       = module.vpc.public_subnets_cidr_blocks
  security_group_id = aws_security_group.jitsi_jvb.id
}


# Egress Internet rule
resource "aws_security_group_rule" "egress_jitsi_jvb" {

  description = "Outgoing traffic"
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.jitsi_jvb.id
}

# ##############################################################
# Task Definition
# ##############################################################

resource "aws_ecs_task_definition" "jitsi_jvb" {
  family                   = "${local.resources_prefix}-jitsi-jvb"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 4096

  # awslogs driver configuration redirect every stdout output to cloudwatch logs
  container_definitions = jsonencode(
    [
      {
        essential = true,
        image     = var.jitsi_images.jvb,
        name      = "jvb",
        secrets = [
          {
            name      = "JVB_AUTH_PASSWORD"
            valueFrom = aws_ssm_parameter.jitsi_passwords["JVB_AUTH_PASSWORD"].arn
          }
        ]
        environment = [
          # TODO: see available params in docker-compose.yaml
          {
            name  = "PUBLIC_URL",
            value = "https://${var.domain_name}",
          }
          # FIXME: must set JVB_ADVERTISE_IPS for STUN anounces behind load balancer ?
        ],
        portMappings = [
          {
            # Traffic port
            containerPort = 10000,
            hostPort      = 10000,
            protocol      = "udp"
          },
          {
            # Traffic port when UDP is not available
            # FIXME: to remove ?
            containerPort = 4443,
            hostPort      = 4443,
            protocol      = "tcp"
          },
          {
            # Health checks
            containerPort = 8080,
            hostPort      = 8080,
            protocol      = "tcp"
          }
        ],
        logConfiguration = {
          logDriver = "awslogs",
          options = {
            awslogs-group         = "${aws_cloudwatch_log_group.jitsi_jvb.name}",
            awslogs-region        = local.current_region,
            awslogs-stream-prefix = "${local.resources_prefix}-jitsi-jvb-"
            mode                  = "non-blocking"
          }
        },
      },
  ])
  task_role_arn      = aws_iam_role.jitsi_jvb.arn
  execution_role_arn = aws_iam_role.task_exe.arn
}

resource "aws_iam_role" "jitsi_jvb" {

  name = "${local.resources_prefix}-jitsi-jvb-task-role"
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

resource "aws_iam_policy" "jitsi_jvb" {
  name = "${local.resources_prefix}-jitsi-jvb-task-policy"
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

resource "aws_iam_role_policy_attachment" "jitsi_jvb" {
  role       = aws_iam_role.jitsi_jvb.id
  policy_arn = aws_iam_policy.jitsi_jvb.arn
}
