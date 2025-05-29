# modules/nat_instance/main.tf

locals {
  # NAT 인스턴스 모듈 내 리소스에 공통적으로 적용될 태그
  module_tags = merge(var.common_tags, {
    TerraformModule = "nat-instance"
    # Name 태그는 각 리소스에서 좀 더 구체적으로 정의
  })
}

# NAT 인스턴스용 최신 Amazon Linux 2 AMI 조회
data "aws_ami" "nat_ami" {
  most_recent = true
  owners      = [var.nat_instance_ami_owner]

  filter {
    name   = "name"
    values = [var.nat_instance_ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# NAT 인스턴스용 탄력적 IP(Elastic IP) 생성
resource "aws_eip" "nat" {
  domain = "vpc" # VPC 스코프의 EIP

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-nat-eip-${var.environment}"
  })
}

# NAT 인스턴스용 보안 그룹
resource "aws_security_group" "nat" {
  name        = "${var.project_name}-nat-instance-sg-${var.environment}"
  description = "Security group for NAT instance, allowing traffic from private subnets and SSH"
  vpc_id      = var.vpc_id

  # 인바운드 규칙:
  # 1. 프라이빗 서브넷들로부터의 모든 트래픽 허용 (var.private_subnet_cidrs 목록 사용)
  dynamic "ingress" {
    for_each = var.private_subnet_cidrs
    content {
      description = "Allow all traffic from Private Subnet ${ingress.key + 1} (${ingress.value})"
      from_port   = 0
      to_port     = 0
      protocol    = "-1" # 모든 프로토콜
      cidr_blocks = [ingress.value]
    }
  }

  # 2. SSH 접근 허용 (관리를 위해, var.my_ip_for_ssh 변수 사용)
  ingress {
    description = "Allow SSH from my IP for NAT instance management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_for_ssh] # 보안을 위해 실제 IP로 변경 권장!
  }

  # 아웃바운드 규칙: 모든 외부 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-nat-sg-${var.environment}" # 이전 VPC 모듈 내 이름과 일관성 유지
  })
}

# NAT EC2 인스턴스 생성
resource "aws_instance" "nat" {
  ami           = data.aws_ami.nat_ami.id
  instance_type = var.nat_instance_type
  subnet_id     = var.public_subnet_id # 퍼블릭 서브넷에 배치
  key_name      = var.ssh_key_name     # SSH 접속용 키 페어 이름 (선택 사항)

  vpc_security_group_ids = [aws_security_group.nat.id]
  source_dest_check      = false # 중요: NAT 인스턴스는 소스/목적지 검사를 비활성화해야 합니다.

  # IP 포워딩 활성화를 위한 User Data (Amazon Linux 2 기준)
  user_data = <<-EOF
              #!/bin/bash
              sudo sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
              sudo sysctl -p /etc/sysctl.conf
              EOF

  user_data_replace_on_change = false # 사용자 데이터 변경 시 교체 안함 (필요에 따라 true)

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-nat-instance-${var.environment}"
  })
}

# EIP를 NAT 인스턴스에 연결
resource "aws_eip_association" "nat" {
  instance_id   = aws_instance.nat.id
  allocation_id = aws_eip.nat.id
}
