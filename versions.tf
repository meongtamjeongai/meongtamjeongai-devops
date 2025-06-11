# terraform-aws-fastapi-infra/versions.tf

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

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}