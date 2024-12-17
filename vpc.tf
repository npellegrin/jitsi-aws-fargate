
#
# We use the VPC Terraform module here for convenience.
# Assuming you will deploy or have your own cusom network in real world usecases.
#

locals {
  vpc_cidr            = "10.0.0.0/16"
  vpc_private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  vpc_public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.resources_prefix}-vpc"
  cidr = local.vpc_cidr

  azs             = var.aws_availability_zones
  private_subnets = local.vpc_private_subnets
  public_subnets  = local.vpc_public_subnets

  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Required SSM endpoint for secrets in private subnets. This incur additional costs.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.eu-west-1.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]
}
resource "aws_vpc_endpoint_subnet_association" "ssm" {
  count           = length(module.vpc.private_subnets)
  vpc_endpoint_id = aws_vpc_endpoint.ssm.id
  subnet_id       = module.vpc.private_subnets[count.index]
}

# Required CloudWatch endpoint for logging in private subnets. This incur additional costs.
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.eu-west-1.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]
}
resource "aws_vpc_endpoint_subnet_association" "logs" {
  count           = length(module.vpc.private_subnets)
  vpc_endpoint_id = aws_vpc_endpoint.logs.id
  subnet_id       = module.vpc.private_subnets[count.index]
}

# Required ECR endpoint for private registries. This incur additional costs.
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.eu-west-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]
}
resource "aws_vpc_endpoint_subnet_association" "ecr_api" {
  count           = length(module.vpc.private_subnets)
  vpc_endpoint_id = aws_vpc_endpoint.ecr_api.id
  subnet_id       = module.vpc.private_subnets[count.index]
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.eu-west-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]
}
resource "aws_vpc_endpoint_subnet_association" "ecr_dkr" {
  count           = length(module.vpc.private_subnets)
  vpc_endpoint_id = aws_vpc_endpoint.ecr_dkr.id
  subnet_id       = module.vpc.private_subnets[count.index]
}

# Required S3 endpoint for pulling data from registries.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )
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
  cidr_blocks       = [local.vpc_cidr]
  security_group_id = aws_security_group.endpoints.id
}
resource "aws_security_group_rule" "endpoints_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = [local.vpc_cidr]
  security_group_id = aws_security_group.endpoints.id
}
