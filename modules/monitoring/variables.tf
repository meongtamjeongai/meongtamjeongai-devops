# modules/monitoring/variables.tf

variable "project_name" {
  description = "Project name (used for resource naming)."
  type        = string
}

variable "environment" {
  description = "Deployment environment (used for resource naming)."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the resources are located."
  type        = string
}

variable "backend_asg_name" {
  description = "The name of the backend EC2 Auto Scaling Group."
  type        = string
}

variable "rds_instance_identifier" {
  description = "The identifier of the RDS DB instance."
  type        = string
}

variable "alarm_notification_email" {
  description = "The email address to receive alarm notifications. Must be confirmed via subscription link."
  type        = string
  default     = null # 이메일이 제공되지 않으면 알람 관련 리소스 생성 안 함
}