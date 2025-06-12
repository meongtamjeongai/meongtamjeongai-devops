# modules/ec2_backend/outputs.tf

output "asg_name" {
  description = "생성된 Auto Scaling Group의 이름"
  value       = aws_autoscaling_group.ec2_backend_asg.name
}

output "asg_arn" {
  description = "생성된 Auto Scaling Group의 ARN"
  value       = aws_autoscaling_group.ec2_backend_asg.arn
}

output "launch_template_id" {
  description = "생성된 시작 템플릿의 ID"
  value       = aws_launch_template.ec2_backend_lt.id
}

output "launch_template_latest_version" {
  description = "생성된 시작 템플릿의 최신 버전 번호"
  value       = aws_launch_template.ec2_backend_lt.latest_version
}

output "security_group_id" {
  description = "EC2 백엔드 인스턴스용 보안 그룹 ID (ALB 설정 시 필요)"
  value       = aws_security_group.ec2_backend_sg.id
}

output "iam_role_arn" {
  description = "EC2 백엔드 인스턴스용 IAM 역할의 ARN"
  value       = aws_iam_role.ec2_backend_role.arn
}

output "iam_instance_profile_arn" {
  description = "EC2 백엔드 인스턴스용 IAM 인스턴스 프로파일의 ARN"
  value       = aws_iam_instance_profile.ec2_backend_profile.arn
}

output "iam_role_name" {
  description = "EC2 백엔드 인스턴스에 대한 IAM 역할의 이름입니다."
  value       = aws_iam_role.ec2_backend_role.name
}