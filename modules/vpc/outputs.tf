# modules/vpc/outputs.tf

output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC에 할당된 CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" { # 👈 이름 변경 및 값 수정
  description = "생성된 모든 퍼블릭 서브넷의 ID 목록"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "public_subnet_cidr_block" {
  description = "퍼블릭 서브넷에 할당된 CIDR 블록"
  value       = aws_subnet.public.cidr_block
}

output "public_subnet_availability_zone" {
  description = "퍼블릭 서브넷이 위치한 가용 영역"
  value       = aws_subnet.public.availability_zone
}

output "private_app_subnet_id" {
  description = "생성된 애플리케이션용 프라이빗 서브넷의 ID"
  value       = aws_subnet.private_app.id
}

output "private_app_subnet_cidr_block" {
  description = "애플리케이션용 프라이빗 서브넷에 할당된 CIDR 블록"
  value       = aws_subnet.private_app.cidr_block
}

output "private_app_subnet_availability_zone" {
  description = "애플리케이션용 프라이빗 서브넷이 위치한 가용 영역"
  value       = aws_subnet.private_app.availability_zone
}

output "private_db_subnet_id" {
  description = "생성된 데이터베이스용 프라이빗 서브넷의 ID"
  value       = aws_subnet.private_db.id
}

output "private_db_subnet_cidr_block" {
  description = "데이터베이스용 프라이빗 서브넷에 할당된 CIDR 블록"
  value       = aws_subnet.private_db.cidr_block
}

output "private_db_subnet_availability_zone" {
  description = "데이터베이스용 프라이빗 서브넷이 위치한 가용 영역"
  value       = aws_subnet.private_db.availability_zone
}

output "private_app_route_table_id" {
  description = "애플리케이션용 프라이빗 서브넷에 연결된 라우트 테이블의 ID"
  value       = aws_route_table.private_app.id
}

output "private_db_route_table_id" {
  description = "데이터베이스용 프라이빗 서브넷에 연결된 라우트 테이블의 ID"
  value       = aws_route_table.private_db.id
}
