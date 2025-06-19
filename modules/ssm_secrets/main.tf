# modules/ssm_secrets/main.tf

# 데이터베이스 전체 URL을 구성하여 파라미터로 저장
resource "aws_ssm_parameter" "database_url" {
  name  = "/${var.project_name}/${var.environment}/DATABASE_URL"
  type  = "SecureString"
  value = "postgresql://${var.db_instance_username}:${var.db_password}@${var.db_instance_endpoint}/${var.db_instance_name}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "fastapi_secret_key" {
  name  = "/${var.project_name}/${var.environment}/FASTAPI_SECRET_KEY"
  type  = "SecureString"
  value = var.fastapi_secret_key
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "firebase_b64_json" {
  name  = "/${var.project_name}/${var.environment}/FIREBASE_B64_JSON"
  type  = "SecureString"
  value = var.firebase_b64_json
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "gemini_api_key" {
  name  = "/${var.project_name}/${var.environment}/GEMINI_API_KEY"
  type  = "SecureString"
  value = var.gemini_api_key
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}