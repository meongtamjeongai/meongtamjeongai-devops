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
  source = "./modules/ec2_backend" # ./modules/ec2_backend 디렉토리 참조

  # 필수 입력 변수 전달
  project_name           = var.project_name
  environment            = var.environment
  common_tags            = local.common_tags
  vpc_id                 = module.vpc.vpc_id                          # VPC 모듈 출력값
  private_app_subnet_ids = [module.vpc.private_app_subnet_id]         # VPC 모듈 출력값 (현재 단일 앱 서브넷)
  ami_id                 = data.aws_ami.amazon_linux_2_for_backend.id # 위에서 조회한 AMI ID

  # 선택적 입력 변수 전달 (필요시 루트 variables.tf 에서 관리 가능)
  instance_type = "t2.micro"        # 프리티어 (또는 var.backend_instance_type 등으로 변경 가능)
  ssh_key_name  = var.ssh_key_name  # 루트 변수 사용 (디버깅용)
  my_ip_for_ssh = var.my_ip_for_ssh # 루트 변수 사용 (디버깅용)

  # ASG 설정 (모듈 기본값 사용 또는 루트 변수로 오버라이드)
  # asg_min_size              = 1
  # asg_max_size              = 2
  # asg_desired_capacity      = 1

  # FastAPI Docker 이미지 (모듈 기본값 사용 또는 루트 변수로 오버라이드)
  # fastapi_docker_image      = "my-docker-registry/my-fastapi-app:latest"
  # fastapi_app_port          = 8000 # 컨테이너 내부 포트가 다른 경우

  # 의존성: NAT 인스턴스가 준비된 후 EC2 인스턴스가 생성되도록 (Docker 이미지 pull 등)
  depends_on = [module.nat_instance]
}
