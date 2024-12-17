output "jitsi_meet_endpoint" {
  value = "https://${aws_route53_record.jitsi_public.fqdn}"
}
