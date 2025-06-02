# modules/rds/outputs.tf

output "db_instance_endpoint" {
  description = "RDS DB 인스턴스의 연결 엔드포인트 주소"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "RDS DB 인스턴스가 리스닝하는 포트"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "RDS DB 인스턴스 생성 시 지정한 초기 데이터베이스 이름 (엔진에 따라 실제 생성 여부 다름)"
  value       = aws_db_instance.main.db_name # 모듈 변수 var.db_name 과 동일할 것임
}

output "db_instance_identifier" {
  description = "RDS DB 인스턴스의 고유 식별자"
  value       = aws_db_instance.main.identifier
}

output "db_instance_username" {
  description = "RDS DB 인스턴스의 마스터 사용자 이름"
  value       = aws_db_instance.main.username # 모듈 변수 var.db_username 과 동일할 것임
  sensitive   = true                          # 사용자 이름도 민감 정보로 간주될 수 있음
}

output "db_instance_arn" {
  description = "RDS DB 인스턴스의 ARN"
  value       = aws_db_instance.main.arn
}

output "db_subnet_group_name" {
  description = "생성된 DB 서브넷 그룹의 이름"
  value       = aws_db_subnet_group.main.name
}

output "rds_security_group_id" {
  description = "RDS DB 인스턴스에 연결된 보안 그룹의 ID"
  value       = aws_security_group.rds_sg.id
}
