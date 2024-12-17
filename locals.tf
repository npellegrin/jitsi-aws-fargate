locals {
  current_account_id = data.aws_caller_identity.current.account_id
  current_region     = data.aws_region.current.name
  resources_prefix   = "jitsi-meet"
}
