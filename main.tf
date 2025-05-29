# terraform-aws-fastapi-infra/main.tf

terraform {
  required_version = ">= 1.12.0"

  cloud {
    organization = "meongtamjeongai" # 👈 실제 Terraform Cloud 조직 이름으로 변경하세요!
    workspaces {
      name = "meongtamjeongai-devops" # 👈 실제 Terraform Cloud 작업 공간 이름으로 변경하세요!
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
    CreatedAt   = timestamp() # 생성 시간 태그 (현재 시간을 기록)
  }
}

# VPC 모듈 호출
module "vpc" {
  source = "./modules/vpc" # ./modules/vpc 디렉토리를 참조

  # modules/vpc/variables.tf 에 정의된 변수들에게 값 전달
  aws_region        = var.aws_region
  project_name      = var.project_name
  environment       = var.environment
  common_tags       = local.common_tags
  availability_zone = var.availability_zone # 루트 variables.tf 에 새로 추가된 변수

  # 필요에 따라 VPC 및 서브넷 CIDR 기본값을 여기서 오버라이드 할 수 있습니다.
  # 예시:
  # vpc_cidr_block          = "10.100.0.0/16"
  # public_subnet_cidr      = "10.100.1.0/24"
  # private_subnet_app_cidr = "10.100.2.0/24"
  # private_subnet_db_cidr  = "10.100.3.0/24"
}
