# modules/nat_instance/main.tf

locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "nat-instance"
  })
}

# 🎯 1. NAT 인스턴스용 IAM 역할 및 인스턴스 프로파일 생성 (SSM 접근용)
resource "aws_iam_role" "nat_instance_role" {
  name = "${var.project_name}-nat-instance-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = local.module_tags
}

resource "aws_iam_role_policy_attachment" "nat_ssm_policy" {
  role       = aws_iam_role.nat_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # SSM Agent 작동에 필요한 기본 권한
}

resource "aws_iam_role_policy_attachment" "nat_ecr_ro_policy" {
  role       = aws_iam_role.nat_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "nat_instance_profile" {
  name = "${var.project_name}-nat-instance-profile-${var.environment}"
  role = aws_iam_role.nat_instance_role.name
  tags = local.module_tags
}

# NAT 인스턴스용 최신 Amazon Linux 2 AMI 조회 (기존과 동일)
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

# NAT 인스턴스용 보안 그룹
resource "aws_security_group" "nat" {
  name        = "${var.project_name}-nat-instance-sg-${var.environment}"
  description = "Security group for NAT instance, allowing traffic from private subnets" # 설명 업데이트
  vpc_id      = var.vpc_id

  # 인바운드 규칙: 프라이빗 서브넷들로부터의 모든 트래픽 허용 (기존과 동일)
  dynamic "ingress" {
    for_each = var.private_subnet_cidrs
    content {
      description = "Allow all traffic from Private Subnet ${ingress.key + 1} (${ingress.value})"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [ingress.value]
    }
  }

  # 🎯 추가: 관리자 앱 포트로의 인바운드 규칙
  ingress {
    description     = "Allow access to Admin App from specified IPs"
    from_port       = var.admin_app_port
    to_port         = var.admin_app_port
    protocol        = "tcp"
    cidr_blocks     = var.admin_app_source_cidrs
  }
  
  # 아웃바운드 규칙: 모든 외부 트래픽 허용 (기존과 동일)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-nat-sg-${var.environment}"
  })
}

# NAT EC2 인스턴스 생성
resource "aws_instance" "nat" {
  ami           = data.aws_ami.nat_ami.id
  instance_type = var.nat_instance_type
  subnet_id     = var.public_subnet_id

  # 🎯 IAM 인스턴스 프로파일 연결
  iam_instance_profile = aws_iam_instance_profile.nat_instance_profile.name

  vpc_security_group_ids = [aws_security_group.nat.id]
  source_dest_check      = false

  user_data = <<-EOF
              #!/bin/bash
              # Enable IP forwarding
              echo "Enabling IP forwarding..."
              sudo sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.conf
              sudo sysctl -p /etc/sysctl.conf
              echo "IP forwarding enabled."

              # Install iptables-services to make rules persistent (for Amazon Linux 2)
              echo "Installing iptables-services..."
              sudo yum install -y iptables-services
              echo "iptables-services installed."

              PRIMARY_INTERFACE=$(ip route | grep default | sed -e "s/^.*dev \([^ ]*\).*$/\1/")
              if [ -z "$PRIMARY_INTERFACE" ]; then
                echo "ERROR: Could not determine primary network interface."
                exit 1
              fi
              echo "Primary network interface: $PRIMARY_INTERFACE"

              echo "Adding MASQUERADE rule for $PRIMARY_INTERFACE..."
              sudo iptables -t nat -A POSTROUTING -o $PRIMARY_INTERFACE -j MASQUERADE
              echo "MASQUERADE rule added."

              echo "Saving iptables rules..."
              sudo iptables-save | sudo tee /etc/sysconfig/iptables
              echo "iptables rules saved."

              echo "Enabling and starting iptables service..."
              sudo systemctl enable iptables
              sudo systemctl start iptables
              echo "iptables service enabled and started."

              # Docker 설치 및 활성화 (관리자 앱 실행용)
              echo "Installing Docker..."
              sudo yum update -y -q
              sudo amazon-linux-extras install docker -y -q
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -a -G docker ec2-user
              echo "Docker installed and started."

              echo "NAT configuration completed."
              EOF

  user_data_replace_on_change = true

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-nat-instance-${var.environment}"
  })
}
