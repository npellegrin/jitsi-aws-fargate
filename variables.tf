
variable "allowed_account_ids" {
  type        = list(string)
  description = "Allowed AWS accounts"
}

variable "domain_name" {
  type        = string
  description = "Jitsi public DNS"
}

variable "hosted_zone_id" {
  type        = string
  description = "Jitsi public zone domaine"
}

variable "jitsi_images" {
  description = "References to Jisti components Docker images. If you use the private registries deployed in this demo, the images must be prefixed by <AWS account id>.dkr.ecr.eu-west-1.amazonaws.com/jitsi-meet-mirror/"

  type = object({
    jicofo  = string
    jvb     = string
    prosody = string
    web     = string
  })

  default = {
    jicofo  = "jitsi/jicofo",
    jvb     = "jitsi/jvb",
    prosody = "jitsi/prosody",
    web     = "jitsi/web",
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to use"
  default     = "eu-west-1"
}

variable "aws_availability_zones" {
  type        = list(string)
  description = "AWS Availability zones to use"
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "vpc_cidr" {
  description = "CIDR block of VPC."
  default     = "10.0.0.0/16"
}
variable "vpc_private_subnets" {
  description = "CIDR block of VPC private subnets."
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "vpc_public_subnets" {
  description = "CIDR block of VPC public subnets."
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "deploy_in_private_subnets" {
  description = "When TRUE, will deploy Jitsi services in a private network, without public IPs. Additional costs for VPC endpoints are expected with a private network setup."
  default     = false
}