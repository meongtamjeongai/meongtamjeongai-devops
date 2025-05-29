# terraform-aws-fastapi-infra/variables.tf

variable "aws_region" {
  description = "AWS 리소스를 배포할 리전입니다."
  type        = string
  default     = "ap-northeast-2" # 서울 리전
}

variable "project_name" {
  description = "프로젝트 이름 태그 등에 사용됩니다."
  type        = string
  default     = "fastapi-infra"
}

variable "environment" {
  description = "배포 환경 (예: dev, stg, prod)"
  type        = string
  default     = "dev"
}

variable "availability_zone" {
  description = "리소스를 배포할 단일 가용 영역 (예: ap-northeast-2a)"
  type        = string
  default     = "ap-northeast-2a"
}
