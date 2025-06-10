# modules/alb/outputs.tf

output "alb_dns_name" {
  description = "생성된 Application Load Balancer의 DNS 이름"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "생성된 Application Load Balancer의 Canonical Hosted Zone ID (Route 53 별칭 레코드용)"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "생성된 Application Load Balancer의 ARN"
  value       = aws_lb.main.arn
}

output "http_listener_arn" {
  description = "HTTP 리스너의 ARN"
  # 단일 리소스이므로 인덱스([0]) 없이 직접 .arn 속성 참조
  value = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "HTTPS 리스너의 ARN (생성된 경우)"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "security_group_id" {
  description = "ALB에 연결된 보안 그룹의 ID"
  value       = aws_security_group.alb_sg.id
}

# FastAPI 앱 대상 그룹 ARN 출력 (이름 변경)
output "fastapi_app_target_group_arn" {
  description = "The ARN of the target group for the FastAPI application."
  value       = aws_lb_target_group.fastapi_app.arn
}

# 관리자 앱 대상 그룹 ARN 출력 (새로 추가)
output "admin_app_target_group_arn" {
  description = "The ARN of the target group for the admin application."
  value       = var.create_admin_target_group ? aws_lb_target_group.admin_app[0].arn : null
}

# ⭐️ 'internal = false'인 ALB의 dns_name은 public DNS이지만, VPC 내부에서는 private IP로 해석됩니다. 그대로 사용해도 무방합니다.
output "alb_dns_name_internal" {
  description = "The internal DNS name of the load balancer. This is used for VPC-internal traffic."
  value       = aws_lb.main.dns_name
}