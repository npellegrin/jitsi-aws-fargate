
locals {
  jitsi_passwords = toset([
    "JICOFO_AUTH_PASSWORD",
    "JVB_AUTH_PASSWORD",
    "JIGASI_XMPP_PASSWORD",
    "JIBRI_RECORDER_PASSWORD",
    "JIBRI_XMPP_PASSWORD",
  ])
}

# Secrets (encrypted parameters)
resource "random_password" "jitsi_passwords" {
  for_each = local.jitsi_passwords
  length   = 16
  special  = false
}
resource "aws_ssm_parameter" "jitsi_passwords" {
  for_each = local.jitsi_passwords
  name     = "/${local.resources_prefix}/${each.key}"
  type     = "SecureString"
  value    = random_password.jitsi_passwords[each.key].result
}

# Non-secrets (non encrypted parameters)
# TODO
