# modules/monitoring/outputs.tf

output "dashboard_name" {
  description = "The name of the created CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "alarms_sns_topic_arn" {
  description = "The ARN of the SNS topic for alarms."
  # 이메일이 제공되었을 때만 값이 있고, 아닐 경우 null
  value       = length(aws_sns_topic.alarms) > 0 ? aws_sns_topic.alarms[0].arn : null
}