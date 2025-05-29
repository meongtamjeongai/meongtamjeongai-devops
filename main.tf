# terraform-aws-fastapi-infra/main.tf

terraform {
  required_version = ">= 1.12.0" # Terraform 최소 권장 버전

  # Terraform Cloud 연동 설정
  # VCS 기반 워크플로우에서는 이 블록이 없어도 TFC가 자동으로 workspace와 연결하지만,
  # 명시적으로 선언해두면 로컬에서 `terraform init` 시 혼동을 줄일 수 있습니다.
  cloud {
    organization = "meongtamjeongai"
    workspaces {
      name = "meongtamjeongai-devops"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}

# VPC 모듈 호출
module "vpc" {
  source = "./modules/vpc"

  aws_region        = var.aws_region
  project_name      = var.project_name
  environment       = var.environment
  common_tags       = local.common_tags
  availability_zone = var.availability_zone

  # 루트 variables.tf에 정의된 CIDR 값들을 명시적으로 전달
  vpc_cidr_block          = var.vpc_cidr_block
  public_subnet_cidr      = var.public_subnet_cidr
  private_subnet_app_cidr = var.private_subnet_app_cidr
  private_subnet_db_cidr  = var.private_subnet_db_cidr
}

# NAT 인스턴스 모듈 호출
module "nat_instance" {
  source = "./modules/nat_instance"

  project_name         = var.project_name
  environment          = var.environment
  common_tags          = local.common_tags
  public_subnet_id     = module.vpc.public_subnet_id                               # VPC 모듈의 출력값 사용
  vpc_id               = module.vpc.vpc_id                                         # VPC 모듈의 출력값 사용
  private_subnet_cidrs = [var.private_subnet_app_cidr, var.private_subnet_db_cidr] # 루트 변수를 리스트로 구성하여 전달

  # nat_instance_type 등은 NAT 모듈 내 기본값 사용
  ssh_key_name  = var.ssh_key_name
  my_ip_for_ssh = var.my_ip_for_ssh

  depends_on = [module.vpc] # VPC가 먼저 생성되도록 의존성 명시
}

# 프라이빗 라우트 테이블에 NAT 인스턴스로 향하는 라우팅 규칙 추가
resource "aws_route" "private_app_subnet_to_nat" {
  route_table_id         = module.vpc.private_app_route_table_id            # VPC 모듈 출력: 앱 라우트 테이블 ID
  destination_cidr_block = "0.0.0.0/0"                                      # 모든 외부 트래픽
  network_interface_id   = module.nat_instance.primary_network_interface_id # NAT 인스턴스 모듈 출력: ENI ID

  # NAT 인스턴스가 완전히 준비된 후 라우트가 추가되도록 명시적 의존성 설정 (선택적이지만 권장)
  depends_on = [module.nat_instance]
}

resource "aws_route" "private_db_subnet_to_nat" {
  route_table_id         = module.vpc.private_db_route_table_id             # VPC 모듈 출력: DB 라우트 테이블 ID
  destination_cidr_block = "0.0.0.0/0"                                      # 모든 외부 트래픽
  network_interface_id   = module.nat_instance.primary_network_interface_id # NAT 인스턴스 모듈 출력: ENI ID

  depends_on = [module.nat_instance]
}

# NAT 인스턴스 임시 테스트용도

data "aws_ami" "amazon_linux_2_test" {
  most_recent = true
  owners      = ["amazon"] # Amazon 제공 AMI

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Amazon Linux 2 최신 버전
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "private_test_instance_sg" {
  name        = "${var.project_name}-private-test-sg-${var.environment}"
  description = "Security group for private test instance (allow all egress)"
  vpc_id      = module.vpc.vpc_id # VPC 모듈의 출력값 사용

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-test-sg-${var.environment}"
  })
}

resource "aws_instance" "private_nat_test" {
  ami           = data.aws_ami.amazon_linux_2_test.id
  instance_type = "t2.micro"                       # 프리티어 활용
  subnet_id     = module.vpc.private_app_subnet_id # 프라이빗 앱 서브넷에 배포

  vpc_security_group_ids = [aws_security_group.private_test_instance_sg.id]
  # associate_public_ip_address = false # 프라이빗 서브넷이므로 기본값 false, 명시적으로도 false

  # User Data 스크립트: 부팅 시 실행되어 외부 통신 테스트
  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "--- $(date) --- Starting NAT connectivity test from private instance ---"
              
              echo "1. Attempting to update yum package list (tests DNS and HTTP/HTTPS to repositories via NAT)..."
              sudo yum update -y
              if [ $? -eq 0 ]; then
                echo "SUCCESS: yum update completed."
              else
                echo "FAILURE: yum update failed. Check NAT instance, routes, SGs, and NACLs."
              fi
              echo ""

              echo "2. Attempting curl to google.com (tests general HTTPS outbound via NAT)..."
              curl -I --connect-timeout 10 https://www.google.com
              if [ $? -eq 0 ]; then
                echo "SUCCESS: curl to https://www.google.com succeeded."
              else
                echo "FAILURE: curl to https://www.google.com failed."
              fi
              echo ""

              echo "3. Attempting ping to 8.8.8.8 (tests ICMP outbound via NAT)..."
              ping -c 3 8.8.8.8
              if [ $? -eq 0 ]; then
                echo "SUCCESS: ping to 8.8.8.8 succeeded."
              else
                echo "FAILURE: ping to 8.8.8.8 failed. (Note: ICMP might be blocked by intermediate firewalls/SGs even if NAT works for TCP/UDP)."
              fi
              echo ""
              
              echo "--- $(date) --- NAT connectivity test finished ---"
              EOF

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-private-nat-test-${var.environment}"
    Purpose = "NAT Connectivity Test"
  })

  # NAT 인스턴스 및 라우팅이 준비된 후에 이 테스트 인스턴스가 생성되도록 의존성 추가
  depends_on = [
    module.nat_instance,
    aws_route.private_app_subnet_to_nat, # 앱 서브넷에 라우트가 적용된 후
    aws_route.private_db_subnet_to_nat   # (선택적) DB 서브넷 라우트도 완료된 후
  ]
}
