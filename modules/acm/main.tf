# modules/acm/main.tf

locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "acm"
    Name            = "${var.project_name}-acm-cert-${var.environment}"
  })
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = local.module_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Cloudflare DNS 레코드 생성을 위한 데이터 준비
# aws_acm_certificate.this.domain_validation_options는 set of objects이므로 for_each 사용
# 각 검증 대상 도메인(주 도메인 및 SAN)에 대해 Cloudflare 레코드를 생성합니다.
resource "cloudflare_dns_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  value   = each.value.value
  type    = each.value.type
  proxied = false
  ttl     = 1 # 또는 60, 120 등 DNS 전파를 위한 짧은 TTL
}

# ACM 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn

  validation_record_fqdns = [
    # cloudflare_dns_record 리소스의 'hostname' 속성이 FQDN을 제공합니다.
    for record in cloudflare_dns_record.validation : record.hostname
  ]

  depends_on = [cloudflare_dns_record.validation]
}
