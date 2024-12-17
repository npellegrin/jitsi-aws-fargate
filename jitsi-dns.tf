# Default internal Jitsi domain is meet.jitsi
#
# We could have use a custom internal domain,
# but it would require to change env variables
# XMPP_DOMAIN, XMPP_AUTH_DOMAIN, XMPP_SERVER, and so on.
# See: https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker/#advanced-configuration

resource "aws_route53_zone" "jitsi" {
  name = "meet.jitsi"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

# Base XMPP service
resource "aws_route53_record" "jitsi" {
  zone_id = aws_route53_zone.jitsi.zone_id
  name    = "meet.jitsi"
  type    = "A"

  alias {
    name                   = "prosody.jitsi.internal"
    zone_id                = aws_service_discovery_private_dns_namespace.jitsi.hosted_zone
    evaluate_target_health = false
  }
}

# Prosody service discovery on xmpp.meet.jitsi (required for signaling)
resource "aws_route53_record" "jitsi_xmpp" {
  zone_id = aws_route53_zone.jitsi.zone_id
  name    = "xmpp.meet.jitsi"
  type    = "A"

  alias {
    name                   = "prosody.jitsi.internal"
    zone_id                = aws_service_discovery_private_dns_namespace.jitsi.hosted_zone
    evaluate_target_health = false
  }
}

# Authenticated XMPP service discovery on auth.meet.jitsi
resource "aws_route53_record" "jitsi_auth" {
  zone_id = aws_route53_zone.jitsi.zone_id
  name    = "auth.meet.jitsi"
  type    = "A"

  alias {
    name                   = "prosody.jitsi.internal"
    zone_id                = aws_service_discovery_private_dns_namespace.jitsi.hosted_zone
    evaluate_target_health = false
  }
}

# MUC service discovery on muc.meet.jitsi
resource "aws_route53_record" "jitsi_muc" {
  zone_id = aws_route53_zone.jitsi.zone_id
  name    = "muc.meet.jitsi"
  type    = "A"

  alias {
    name                   = "prosody.jitsi.internal"
    zone_id                = aws_service_discovery_private_dns_namespace.jitsi.hosted_zone
    evaluate_target_health = false
  }
}

# Internal MUC service discovery on muc.meet.jitsi
resource "aws_route53_record" "jitsi_internal_muc" {
  zone_id = aws_route53_zone.jitsi.zone_id
  name    = "internal-muc.meet.jitsi"
  type    = "A"

  alias {
    name                   = "prosody.jitsi.internal"
    zone_id                = aws_service_discovery_private_dns_namespace.jitsi.hosted_zone
    evaluate_target_health = false
  }
}

# XMPP domain for unauthenticated users
resource "aws_route53_record" "jitsi_guest" {
  zone_id = aws_route53_zone.jitsi.zone_id
  name    = "guest.meet.jitsi"
  type    = "A"

  alias {
    name                   = "prosody.jitsi.internal"
    zone_id                = aws_service_discovery_private_dns_namespace.jitsi.hosted_zone
    evaluate_target_health = false
  }
}

# Jitsi web public DNS
resource "aws_route53_record" "jitsi_public" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.jitsi_public.dns_name]
}
