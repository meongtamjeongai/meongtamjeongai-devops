# modules/ssm_secrets/outputs.tf

output "parameter_names" {
  description = "A map of created SSM parameter names."
  value = {
    DATABASE_URL       = aws_ssm_parameter.database_url.name
    FASTAPI_SECRET_KEY = aws_ssm_parameter.fastapi_secret_key.name
    FIREBASE_B64_JSON  = aws_ssm_parameter.firebase_b64_json.name
    GEMINI_API_KEY     = aws_ssm_parameter.gemini_api_key.name
  }
}