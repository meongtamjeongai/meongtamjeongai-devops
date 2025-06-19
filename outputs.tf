# ==============================================================================
# 📄 모듈 출력 (Outputs)
# Terraform apply 후 생성된 리소스의 주요 정보를 출력합니다.
# ==============================================================================


## 🌐 VPC & 네트워킹
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC의 ID"
  value       = module.vpc.vpc_id
  sensitive   = false # ID는 민감 정보가 아닙니다.
}

output "all_public_subnet_ids" {
  description = "모든 퍼블릭 서브넷의 ID 목록"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_id" {
  description = "애플리케이션용 프라이빗 서브넷의 ID"
  value       = module.vpc.private_app_subnet_id
}

output "all_private_db_subnet_ids" {
  description = "모든 데이터베이스용 프라이빗 서브넷의 ID 목록"
  value       = module.vpc.private_db_subnet_ids
}

output "private_app_route_table_id" {
  description = "애플리케이션 프라이빗 라우트 테이블 ID (NAT 라우팅용)"
  value       = module.vpc.private_app_route_table_id
}

output "private_db_route_table_id" {
  description = "데이터베이스 프라이빗 라우트 테이블 ID (NAT 라우팅용)"
  value       = module.vpc.private_db_route_table_id
}

## 🔒 NAT 인스턴스
# ------------------------------------------------------------------------------
output "nat_instance_id" {
  description = "NAT 인스턴스의 ID"
  value       = module.nat_instance.instance_id
}

output "nat_instance_dynamic_public_ip" {
  description = "NAT 인스턴스의 동적 공인 IP (주의: 재시작 시 변경될 수 있음)"
  value       = module.nat_instance.dynamic_public_ip
}

output "nat_instance_private_ip" {
  description = "NAT 인스턴스의 사설 IP"
  value       = module.nat_instance.private_ip
}

output "nat_instance_primary_network_interface_id" {
  description = "NAT 인스턴스의 기본 네트워크 인터페이스(ENI) ID"
  value       = module.nat_instance.primary_network_interface_id
}


## 💻 애플리케이션 컴퓨팅 (EC2 & ASG)
# ------------------------------------------------------------------------------
output "backend_asg_name" {
  description = "백엔드 Auto Scaling Group의 이름"
  value       = module.ec2_backend.asg_name
}

output "backend_security_group_id" {
  description = "백엔드 EC2 인스턴스 보안 그룹 ID (ALB 대상 그룹 설정에 사용)"
  value       = module.ec2_backend.security_group_id
}

output "backend_launch_template_id" {
  description = "백엔드 EC2 인스턴스 시작 템플릿 ID"
  value       = module.ec2_backend.launch_template_id
}


## ⚖️ 로드 밸런서 (ALB) & 인증서 (ACM)
# ------------------------------------------------------------------------------
output "alb_dns_name" {
  description = "애플리케이션 로드 밸런서(ALB)의 DNS 주소 (외부 접속용)"
  value       = module.alb.alb_dns_name
}

output "alb_internal_dns_for_vpc_traffic" {
  description = "VPC 내부 통신용 ALB DNS 이름 (내부 서비스 간 호출 시 사용)"
  value       = module.alb.alb_dns_name
}

output "acm_certificate_arn_validated" {
  description = "검증된 ACM 인증서의 ARN (ALB 리스너용)"
  value       = module.acm.validated_certificate_arn
}


## 🗃️ 데이터베이스 (RDS)
# ------------------------------------------------------------------------------
output "rds_instance_endpoint" {
  description = "RDS DB 인스턴스 연결 엔드포인트 주소"
  value       = module.rds.db_instance_endpoint
  sensitive   = true # 엔드포인트는 민감 정보로 취급하는 것이 안전합니다.
}

output "rds_instance_port" {
  description = "RDS DB 인스턴스 연결 포트"
  value       = module.rds.db_instance_port
}

output "rds_db_name" {
  description = "RDS DB 인스턴스의 초기 데이터베이스 이름"
  value       = module.rds.db_instance_name
}

output "rds_db_username" {
  description = "RDS DB 인스턴스의 마스터 사용자 이름"
  value       = module.rds.db_instance_username
  sensitive   = true
}


## 📦 컨테이너 레지스트리 (ECR)
# ------------------------------------------------------------------------------
output "ecr_repository_url" {
  description = "FastAPI 애플리케이션용 ECR 리포지토리 URL"
  value       = aws_ecr_repository.fastapi_app.repository_url
}

output "admin_app_ecr_repository_url" {
  description = "관리자 애플리케이션용 ECR 리포지토리 URL"
  value       = aws_ecr_repository.admin_app.repository_url
}


## 💾 스토리지 (S3)
# ------------------------------------------------------------------------------
output "s3_image_storage_bucket_name" {
  description = "이미지 저장을 위한 S3 버킷 이름"
  value       = aws_s3_bucket.image_storage.id
}


## 🐛 디버깅용
# ------------------------------------------------------------------------------
output "vpc_module_outputs" {
  description = "VPC 모듈의 모든 출력값 (디버깅용)"
  value       = module.vpc # 모듈 전체를 출력하면 모든 output이 나옵니다.
  sensitive   = true     # 내부에 민감한 정보가 포함될 수 있으므로 true로 설정합니다.
}

## 📊 모니터링 (CloudWatch)
# ------------------------------------------------------------------------------
output "cloudwatch_dashboard_url" {
  description = "CloudWatch 대시보드로 바로 이동할 수 있는 URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
}