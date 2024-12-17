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
  type = object({
    web     = string
    jvb     = string
    jicofo  = string
    prosody = string
  })

  default = {
    web     = "jitsi/web",
    jvb     = "jitsi/jvb",
    jicofo  = "jitsi/jicofo",
    prosody = "jitsi/prosody",
  }
}
