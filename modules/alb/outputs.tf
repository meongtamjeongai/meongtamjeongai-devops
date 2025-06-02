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

output "target_group_arn" {
  description = "생성된 대상 그룹의 ARN (Auto Scaling Group에 연결 시 필요)"
  value       = aws_lb_target_group.main.arn
}

output "target_group_name" {
  description = "생성된 대상 그룹의 이름"
  value       = aws_lb_target_group.main.name
}

output "security_group_id" {
  description = "ALB에 연결된 보안 그룹의 ID"
  value       = aws_security_group.alb_sg.id
}
