
#
# We use the VPC Terraform module here for convenience.
# Assuming you will deploy or have your own cusom network in real world usecases.
#
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.resources_prefix}-fargate"
  cidr = "10.0.0.0/16"

  azs             = var.aws_availability_zones
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
}
