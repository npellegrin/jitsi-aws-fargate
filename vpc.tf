
#
# We use the VPC Terraform module here for convenience.
# Assuming you will deploy or have your own cusom network in real world usecases.
#

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.resources_prefix}-vpc"
  cidr = var.vpc_cidr

  azs = var.aws_availability_zones

  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# S3 endpoint for pulling data from ECR registries.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )
}

# Required SSM endpoint for secrets in private subnets. This incur additional costs.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.eu-west-1.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]
  count               = var.deploy_in_private_subnets ? 1 : 0
}
resource "aws_vpc_endpoint_subnet_association" "ssm" {
  vpc_endpoint_id = aws_vpc_endpoint.ssm[0].id
  subnet_id       = module.vpc.private_subnets[count.index]
  count           = var.deploy_in_private_subnets ? length(module.vpc.private_subnets) : 0
}

# Required CloudWatch endpoint for logging in private subnets. This incur additional costs.
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.eu-west-1.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]
  count               = var.deploy_in_private_subnets ? 1 : 0
}
resource "aws_vpc_endpoint_subnet_association" "logs" {
  vpc_endpoint_id = aws_vpc_endpoint.logs[0].id
  subnet_id       = module.vpc.private_subnets[count.index]
  count           = var.deploy_in_private_subnets ? length(module.vpc.private_subnets) : 0
}

# Required ECR endpoint for private registries. This incur additional costs.
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.eu-west-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]
  count               = var.deploy_in_private_subnets ? 1 : 0
}
resource "aws_vpc_endpoint_subnet_association" "ecr_api" {
  vpc_endpoint_id = aws_vpc_endpoint.ecr_api[0].id
  subnet_id       = module.vpc.private_subnets[count.index]
  count           = var.deploy_in_private_subnets ? length(module.vpc.private_subnets) : 0
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.eu-west-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]
  count               = var.deploy_in_private_subnets ? 1 : 0
}
resource "aws_vpc_endpoint_subnet_association" "ecr_dkr" {
  vpc_endpoint_id = aws_vpc_endpoint.ecr_dkr[0].id
  subnet_id       = module.vpc.private_subnets[count.index]
  count           = var.deploy_in_private_subnets ? length(module.vpc.private_subnets) : 0
}

# Endpoint security group - wide open to all VPC ips
resource "aws_security_group" "endpoints" {
  name   = "${local.resources_prefix}-vpc-endpoints"
  vpc_id = module.vpc.vpc_id
}
resource "aws_security_group_rule" "endpoints_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.endpoints.id
}
resource "aws_security_group_rule" "endpoints_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.endpoints.id
}
