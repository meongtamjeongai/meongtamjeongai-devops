terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source = "cloudflare/cloudflare" # 👈 올바른 소스 주소 명시
      version = "~> 5.0" # 루트 모듈과 동일하게 또는 모듈에 맞는 버전 제약
    }
  }
}
