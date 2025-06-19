# modules/ssm_secrets/variables.tf

variable "project_name" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

# --- 민감 정보 입력 변수들 ---
variable "db_password" {
  type      = string
  sensitive = true
}
variable "fastapi_secret_key" {
  type      = string
  sensitive = true
}
variable "firebase_b64_json" {
  type      = string
  sensitive = true
}
variable "gemini_api_key" {
  type      = string
  sensitive = true
}
variable "db_instance_endpoint" {
  description = "RDS DB instance connection endpoint address"
  type        = string
}
variable "db_instance_username" {
  description = "RDS DB instance's master username"
  type        = string
}
variable "db_instance_name" {
  description = "RDS DB instance's initial database name"
  type        = string
}