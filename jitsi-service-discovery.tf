# Internal service discovery will be mapped to real internal or public domain xmpp.meet.jitsi and others

resource "aws_service_discovery_private_dns_namespace" "jitsi" {
  name        = "jitsi.internal"
  description = "Jitsi internal"
  vpc         = module.vpc.vpc_id
}

# Jitsi Prosody
resource "aws_service_discovery_service" "jitsi_prosody" {
  name = "prosody"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.jitsi.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
