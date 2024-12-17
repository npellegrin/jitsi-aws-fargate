variable "aws_region" {
  type        = string
  description = "AWS region to use"
}

variable "aws_availability_zones" {
  type        = list(string)
  description = "AWS Availability zones to use"
}

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
