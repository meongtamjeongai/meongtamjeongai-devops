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
resource "cloudflare_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
      # Cloudflare API는 name 필드에 FQDN이 아닌, zone에 대한 상대적인 이름을 기대합니다.
      # dvo.resource_record_name은 보통 _abs123.sub.example.com. 형태이므로,
      # zone_name (var.domain_name 또는 SAN의 루트 도메인)을 제거해야 합니다.
      # 여기서는 Cloudflare provider가 zone_id를 기반으로 name을 올바르게 처리한다고 가정합니다.
      # provider가 name에서 zone 부분을 자동으로 처리해줍니다.
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name  # 예: _abs123.www (zone이 example.com 이면 _abs123.www.example.com)
  value   = each.value.value # 예: _def456.ghj.acm-validations.aws.
  type    = each.value.type  # 예: CNAME
  proxied = false            # DNS 검증용이므로 프록시 비활성화
  ttl     = 1                # DNS 전파를 위해 짧은 TTL 권장 (기본값은 1로 자동, 또는 60, 120 등)
}

# ACM 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn

  # validation_record_fqdns에는 Cloudflare에서 생성된 레코드의 FQDN을 전달해야 합니다.
  # cloudflare_record 리소스의 'hostname' 속성이 FQDN을 제공합니다.
  validation_record_fqdns = [
    for record in cloudflare_record.validation : record.hostname
  ]

  # Cloudflare 레코드가 생성된 후 이 리소스가 평가되도록 명시적 의존성 추가
  depends_on = [cloudflare_record.validation]
}
