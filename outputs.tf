# terraform-aws-fastapi-infra/outputs.tf

output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = module.vpc.vpc_id
  sensitive   = false # ID는 민감 정보가 아님
}

output "all_public_subnet_ids" {
  description = "생성된 모든 퍼블릭 서브넷 ID 목록"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_id" {
  description = "생성된 애플리케이션용 프라이빗 서브넷의 ID"
  value       = module.vpc.private_app_subnet_id
}

output "all_private_db_subnet_ids" {
  description = "생성된 모든 프라이빗 DB 서브넷 ID 목록"
  value       = module.vpc.private_db_subnet_ids # 👈 VPC 모듈의 리스트 출력값 전체를 사용
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

output "backend_asg_name" {
  description = "백엔드 Auto Scaling Group의 이름"
  value       = module.ec2_backend.asg_name
}

output "backend_security_group_id" {
  description = "백엔드 EC2 인스턴스용 보안 그룹 ID (ALB 설정에 필요)"
  value       = module.ec2_backend.security_group_id
}

output "backend_launch_template_id" {
  description = "백엔드 EC2 인스턴스용 시작 템플릿 ID"
  value       = module.ec2_backend.launch_template_id
}

output "alb_dns_name" {
  description = "애플리케이션 로드 밸런서의 DNS 주소 (애플리케이션 접속 URL)"
  value       = module.alb.alb_dns_name
}

output "rds_instance_endpoint" {
  description = "RDS DB 인스턴스 연결 엔드포인트 주소"
  value       = module.rds.db_instance_endpoint
}

output "rds_instance_port" {
  description = "RDS DB 인스턴스 연결 포트"
  value       = module.rds.db_instance_port
}

output "rds_db_name" {
  description = "RDS DB 인스턴스의 초기 데이터베이스 이름"
  value       = module.rds.db_instance_name # 모듈 출력값 참조
}

output "rds_db_username" {
  description = "RDS DB 인스턴스의 마스터 사용자 이름"
  value       = module.rds.db_instance_username # 모듈 출력값 참조
  sensitive   = true
}

output "ecr_repository_url" {
  description = "생성된 Amazon ECR 리포지토리의 URL"
  value       = aws_ecr_repository.fastapi_app.repository_url
}

output "acm_certificate_arn_validated" {
  description = "The ARN of the validated ACM certificate used for the ALB."
  value       = module.acm.validated_certificate_arn
}
