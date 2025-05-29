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

output "nat_instance_id" {
  description = "생성된 NAT 인스턴스의 ID"
  value       = module.nat_instance.instance_id
}

output "nat_instance_dynamic_public_ip" {
  description = "NAT 인스턴스에 할당된 동적 공인 IP 주소 (주의: 재시작 시 변경 가능)"
  value       = module.nat_instance.dynamic_public_ip # 모듈의 새 출력 참조
}

output "nat_instance_private_ip" {
  description = "NAT 인스턴스의 사설 IP 주소"
  value       = module.nat_instance.private_ip
}

output "nat_instance_primary_network_interface_id" {
  description = "NAT 인스턴스의 기본 네트워크 인터페이스 ID"
  value       = module.nat_instance.primary_network_interface_id
}
