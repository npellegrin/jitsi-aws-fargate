
provider "aws" {
  region              = var.aws_region
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Environment = "demo"
      Repository  = "https://github.com/npellegrin/jitsi-aws-fargate"
    }
  }
}
