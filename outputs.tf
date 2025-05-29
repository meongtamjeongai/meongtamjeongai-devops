# terraform-aws-fastapi-infra/outputs.tf

output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = module.vpc.vpc_id
  sensitive   = false # ID는 민감 정보가 아님
}

output "public_subnet_id" {
  description = "생성된 퍼블릭 서브넷의 ID"
  value       = module.vpc.public_subnet_id
}

output "private_app_subnet_id" {
  description = "생성된 애플리케이션용 프라이빗 서브넷의 ID"
  value       = module.vpc.private_app_subnet_id
}

output "private_db_subnet_id" {
  description = "생성된 데이터베이스용 프라이빗 서브넷의 ID"
  value       = module.vpc.private_db_subnet_id
}

output "private_app_route_table_id" {
  description = "애플리케이션용 프라이빗 라우트 테이블 ID (NAT 라우팅 추가에 사용)"
  value       = module.vpc.private_app_route_table_id
}

output "private_db_route_table_id" {
  description = "데이터베이스용 프라이빗 라우트 테이블 ID (NAT 라우팅 추가에 사용)"
  value       = module.vpc.private_db_route_table_id
}

output "vpc_module_outputs" {
  description = "VPC 모듈의 모든 출력값 (디버깅용)"
  value       = module.vpc # 모듈 전체를 출력하면 모든 output이 나옴
  sensitive   = true       # 내부적으로 민감한 정보가 있을 수 있으므로 true로 설정 권장
}
