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

# --- NAT 기능 테스트를 위한 임시 리소스들 ---

# 1. EC2 인스턴스용 IAM 역할 및 SSM Session Manager 사용을 위한 인스턴스 프로파일
resource "aws_iam_role" "ssm_ec2_role" {
  name = "${var.project_name}-ssm-ec2-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # AWS 관리형 정책
}

resource "aws_iam_instance_profile" "ssm_ec2_instance_profile" {
  name = "${var.project_name}-ssm-ec2-profile-${var.environment}"
  role = aws_iam_role.ssm_ec2_role.name
  tags = local.common_tags
}

# 2. 테스트용 프라이빗 EC2 인스턴스를 위한 보안 그룹
resource "aws_security_group" "private_test_ec2_sg" {
  name        = "${var.project_name}-private-test-ec2-sg-${var.environment}"
  description = "Allow outbound traffic for private test EC2 instance via NAT"
  vpc_id      = module.vpc.vpc_id # VPC 모듈에서 출력된 VPC ID 사용

  # 아웃바운드: 모든 트래픽 허용 (NAT를 통해 외부로 나감)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 인바운드: SSM Session Manager 사용 시 별도의 인바운드 규칙 불필요.
  # 만약 Bastion Host를 통한 SSH 등을 고려한다면 해당 규칙 추가.
  # 예:
  # ingress {
  #   description     = "Allow SSH from Bastion Host SG"
  #   from_port       = 22
  #   to_port         = 22
  #   protocol        = "tcp"
  #   security_groups = [ "sg-xxxxxxxxxxxxxxxxx" ] # Bastion Host의 보안 그룹 ID
  # }

  tags = local.common_tags
}

# 3. 테스트용 EC2 인스턴스에 사용할 Amazon Linux 2 AMI 조회
data "aws_ami" "amazon_linux_2_for_test" {
  most_recent = true
  owners      = ["amazon"] # Amazon 제공 AMI
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Amazon Linux 2
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 4. 프라이빗 서브넷(애플리케이션용)에 테스트 EC2 인스턴스 생성
resource "aws_instance" "private_test_ec2" {
  ami           = data.aws_ami.amazon_linux_2_for_test.id
  instance_type = "t2.micro"                       # 프리티어
  subnet_id     = module.vpc.private_app_subnet_id # 앱용 프라이빗 서브넷에 배포
  key_name      = var.ssh_key_name                 # var.ssh_key_name (SSM 사용 시 필수는 아님)

  iam_instance_profile   = aws_iam_instance_profile.ssm_ec2_instance_profile.name # SSM 접속용 프로파일
  vpc_security_group_ids = [aws_security_group.private_test_ec2_sg.id]            # 위에서 만든 보안 그룹

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-test-ec2-${var.environment}"
  })

  # NAT 인스턴스로 향하는 라우팅 규칙이 적용된 후에 이 인스턴스가 생성되도록 의존성 명시
  depends_on = [
    aws_route.private_app_subnet_to_nat,
    aws_route.private_db_subnet_to_nat
  ]
}
