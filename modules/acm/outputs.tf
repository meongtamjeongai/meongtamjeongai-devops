# modules/acm/outputs.tf

output "certificate_arn" {
  description = "The ARN of the requested ACM certificate."
  value       = aws_acm_certificate.this.arn
}

output "validated_certificate_arn" {
  description = "The ARN of the ACM certificate after DNS validation is complete. Use this ARN for ALB listeners."
  value       = aws_acm_certificate_validation.this.certificate_arn
  # aws_acm_certificate_validation 리소스는 성공 시 입력 certificate_arn을 그대로 반환합니다.
  # 이 출력을 사용하면 검증이 완료되었음을 보장할 수 있습니다.
}

output "certificate_status" {
  description = "The status of the ACM certificate (e.g., PENDING_VALIDATION, ISSUED, FAILED)."
  value       = aws_acm_certificate.this.status # 검증 전 상태를 보여줄 수 있음
}
