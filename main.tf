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
      version = "~> 5.0" # AWS 프로바이더 버전 (최신 안정 버전 권장)
    }
  }
}

# AWS 프로바이더 구성
provider "aws" {
  region = var.aws_region
  # AWS 자격 증명은 Terraform Cloud에 설정된 환경 변수
  # (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)를 통해 자동으로 주입됩니다.
}

# 공통 태그 설정을 위한 local 변수 (선택 사항이지만 매우 유용)
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  } 
}

# 초기 테스트용 출력
output "aws_provider_setup_status" {
  value = "AWS provider가 성공적으로 구성되었으며, 리전 '${var.aws_region}'에 배포할 준비가 되었습니다. 다음 단계: VPC 구성"
}
