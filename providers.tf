# terraform-aws-fastapi-infra/provider.tf

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  # 테라폼 클라우드에서 CLOUDFLARE_API_TOKEN 환경변수가 자동으로 사용됩니다.
}
