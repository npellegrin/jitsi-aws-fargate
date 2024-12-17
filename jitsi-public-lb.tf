
resource "aws_lb" "jitsi_public" {
  name                       = "${local.resources_prefix}-jitsi-public"
  internal                   = false
  load_balancer_type         = "network"
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false
}

resource "aws_lb_listener" "jitsi_web" {
  load_balancer_arn = aws_lb.jitsi_public.arn
  port              = "443"
  protocol          = "TLS"
  certificate_arn   = aws_acm_certificate.jitsi_public.arn
  alpn_policy       = "HTTP2Preferred"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jitsi_web.arn
  }
}

resource "aws_lb_listener" "jitsi_jvb" {
  load_balancer_arn = aws_lb.jitsi_public.arn
  port              = "10000"
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jitsi_jvb.arn
  }
}

resource "aws_lb_listener" "jitsi_jvb_fallback" {
  load_balancer_arn = aws_lb.jitsi_public.arn
  port              = "4443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jitsi_jvb_fallback.arn
  }
}

resource "aws_acm_certificate" "jitsi_public" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "jitsi_public" {
  certificate_arn         = aws_acm_certificate.jitsi_public.arn
  validation_record_fqdns = [for record in aws_route53_record.jitsi_public_certificate_validation : record.fqdn]
}

resource "aws_route53_record" "jitsi_public_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.jitsi_public.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}
