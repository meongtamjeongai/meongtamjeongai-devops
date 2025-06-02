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

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags

  availability_zones        = var.availability_zones    # 👈 루트의 list(string) 변수 전달
  public_subnet_cidrs       = var.public_subnet_cidrs   # 👈 루트의 list(string) 변수 전달
  primary_availability_zone = var.availability_zones[0] # 👈 프라이빗 서브넷용 AZ (예: 리스트의 첫 번째 AZ 사용)

  # 루트 variables.tf에 정의된 CIDR 값들을 명시적으로 전달
  vpc_cidr_block = var.vpc_cidr_block

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

# 백엔드 EC2 인스턴스용 AMI 조회 (Amazon Linux 2)
data "aws_ami" "amazon_linux_2_for_backend" {
  most_recent = true
  owners      = ["amazon"] # Amazon 제공 AMI

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Amazon Linux 2 최신 HVM GP2 AMI
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 백엔드 모듈 호출
module "ec2_backend" {
  source = "./modules/ec2_backend"

  project_name           = var.project_name
  environment            = var.environment
  common_tags            = local.common_tags
  vpc_id                 = module.vpc.vpc_id
  private_app_subnet_ids = [module.vpc.private_app_subnet_id]
  ami_id                 = data.aws_ami.amazon_linux_2_for_backend.id
  instance_type          = "t2.micro"
  ssh_key_name           = var.ssh_key_name
  my_ip_for_ssh          = var.my_ip_for_ssh
  host_app_port          = var.backend_app_port # 루트의 backend_app_port -> ec2_backend의 host_app_port로 전달

  # 🎯 ALB 대상 그룹 ARN 전달 (아래 alb 모듈 생성 후 연결)
  target_group_arns = [module.alb.target_group_arn] # module.alb가 생성된 후에 이 값이 결정됨

  # 명확한 의존성 선언 (nat_instance 및 alb 모듈이 완료된 후 실행)
  depends_on = [module.vpc, module.nat_instance, module.alb]
}

# ALB 모듈 호출
module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  common_tags       = local.common_tags
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids # 👈 VPC 모듈의 list 출력값 전달

  backend_app_port = var.backend_app_port # 루트의 backend_app_port -> alb의 backend_app_port로 전달

  # HTTPS 사용 시 ACM 인증서 ARN 전달
  # certificate_arn           = "arn:aws:acm:ap-northeast-2:123456789012:certificate/your-cert-id"

  # ALB는 VPC 모듈에만 의존합니다.
  depends_on = [module.vpc]
}

# ALB에서 백엔드 EC2 인스턴스로의 트래픽을 허용하는 보안 그룹 규칙 추가
resource "aws_security_group_rule" "allow_alb_to_backend" {
  type                     = "ingress"
  description              = "Allow traffic from ALB to backend EC2 instances on app port"
  from_port                = var.backend_app_port # 루트의 backend_app_port 사용
  to_port                  = var.backend_app_port # 루트의 backend_app_port 사용
  protocol                 = "tcp"
  security_group_id        = module.ec2_backend.security_group_id # 대상: 백엔드 SG
  source_security_group_id = module.alb.security_group_id         # 소스: ALB SG

  # 이 규칙은 alb와 ec2_backend 모듈이 각각의 SG를 만든 후에 적용됨
  depends_on = [module.alb, module.ec2_backend]
}
