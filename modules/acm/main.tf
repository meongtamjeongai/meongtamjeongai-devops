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
      # dvo.resource_record_name 은 FQDN 형태 (_xyz.example.com.)
      # dvo.resource_record_value 는 CNAME 대상 값
      # dvo.resource_record_type 은 "CNAME"
      name    = dvo.resource_record_name
      content = dvo.resource_record_value
      type    = dvo.resource_record_type
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name # Cloudflare provider가 zone_id 기준으로 처리 (예: _xyz.example.com. -> _xyz)
  content = each.value.content
  type    = each.value.type
  proxied = false
  ttl     = 1
}

# ACM 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn

  # 👈 수정된 부분:
  # aws_acm_certificate 리소스의 domain_validation_options 에서 직접 FQDN을 가져옵니다.
  # 이 값들은 Cloudflare에 생성될 레코드의 이름과 정확히 일치해야 합니다.
  validation_record_fqdns = [
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.resource_record_name
  ]

  # Cloudflare 레코드가 생성된 후 이 리소스가 평가되도록 명시적 의존성 추가
  depends_on = [cloudflare_dns_record.validation]
}
