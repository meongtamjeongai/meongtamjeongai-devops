# modules/nat_instance/main.tf

locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "nat-instance"
  })
}

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

# --- aws_eip 리소스 제거 ---
# resource "aws_eip" "nat" { ... }
# --- aws_eip 리소스 제거 ---

resource "aws_security_group" "nat" {
  name        = "${var.project_name}-nat-instance-sg-${var.environment}"
  description = "Security group for NAT instance, allowing traffic from private subnets and SSH"
  vpc_id      = var.vpc_id

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

  ingress {
    description = "Allow SSH from my IP for NAT instance management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_for_ssh]
  }

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

resource "aws_instance" "nat" {
  ami           = data.aws_ami.nat_ami.id
  instance_type = var.nat_instance_type
  subnet_id     = var.public_subnet_id
  key_name      = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.nat.id]
  source_dest_check      = false
  # EIP를 사용하지 않으므로, 퍼블릭 서브넷의 'map_public_ip_on_launch' 설정에 따라 동적 공인 IP가 할당됩니다.
  # associate_public_ip_address = true # 명시적으로 true로 설정할 수도 있으나, 서브넷 설정에 따르는 것이 일반적입니다.

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

              # Dynamically get the primary network interface
              PRIMARY_INTERFACE=$(ip route | grep default | sed -e "s/^.*dev \([^ ]*\).*$/\1/")
              if [ -z "$PRIMARY_INTERFACE" ]; then
                echo "ERROR: Could not determine primary network interface."
                exit 1
              fi
              echo "Primary network interface: $PRIMARY_INTERFACE"

              # Add MASQUERADE rule for NAT
              echo "Adding MASQUERADE rule for $PRIMARY_INTERFACE..."
              sudo iptables -t nat -A POSTROUTING -o $PRIMARY_INTERFACE -j MASQUERADE
              echo "MASQUERADE rule added."

              # Save the iptables rules
              echo "Saving iptables rules..."
              sudo iptables-save | sudo tee /etc/sysconfig/iptables
              echo "iptables rules saved."

              # Enable and start iptables service
              echo "Enabling and starting iptables service..."
              sudo systemctl enable iptables
              sudo systemctl start iptables
              echo "iptables service enabled and started."
              echo "NAT configuration completed."
              EOF

  user_data_replace_on_change = true # user_data 변경 시 인스턴스를 교체하도록 설정 (iptables 업데이트 등)

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-nat-instance-${var.environment}"
  })
}

# --- aws_eip_association 리소스 제거 ---
# resource "aws_eip_association" "nat" { ... }
# --- aws_eip_association 리소스 제거 ---
