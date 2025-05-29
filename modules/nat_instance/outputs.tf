# modules/nat_instance/outputs.tf

output "instance_id" {
  description = "생성된 NAT EC2 인스턴스의 ID"
  value       = aws_instance.nat.id
}

output "primary_network_interface_id" {
  description = "NAT 인스턴스의 기본 네트워크 인터페이스 ID (라우팅 규칙 설정에 사용)"
  value       = aws_instance.nat.primary_network_interface_id
}

# EIP를 사용하지 않으므로 EIP 관련 출력은 제거
# output "public_ip" {
#   description = "NAT 인스턴스에 할당된 공인 IP 주소 (Elastic IP)"
#   value       = aws_eip.nat.public_ip
# }

output "dynamic_public_ip" {
  description = "NAT 인스턴스에 할당된 동적 공인 IP 주소 (인스턴스 재시작 시 변경될 수 있음)"
  value       = aws_instance.nat.public_ip # 인스턴스의 공인 IP 속성 참조
}

output "private_ip" {
  description = "NAT 인스턴스의 사설 IP 주소"
  value       = aws_instance.nat.private_ip
}

output "security_group_id" {
  description = "NAT 인스턴스에 연결된 보안 그룹의 ID"
  value       = aws_security_group.nat.id
}
