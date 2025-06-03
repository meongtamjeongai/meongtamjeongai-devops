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

resource "cloudflare_dns_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      # 'value'가 아니라 'content'로 DNS 레코드 값을 전달해야 합니다.
      # dvo.resource_record_value는 AWS ACM이 제공하는 CNAME 값입니다.
      record_value = dvo.resource_record_value # for_each 내부에서 사용할 임시 변수명 변경
      type         = dvo.resource_record_type
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name         # 예: _abs123.www (zone이 example.com 이면 _abs123.www.example.com)
  content = each.value.record_value # 👈 "value" 에서 "content" 로 변경, 그리고 each.value.value 대신 each.value.record_value 사용
  type    = each.value.type         # 예: CNAME
  proxied = false
  ttl     = 1 # DNS 전파를 위해 짧은 TTL 권장 (Cloudflare 기본값은 auto)
}

# ACM 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn

  validation_record_fqdns = [
    for record in cloudflare_dns_record.validation : record.hostname
  ]

  depends_on = [cloudflare_dns_record.validation]
}
