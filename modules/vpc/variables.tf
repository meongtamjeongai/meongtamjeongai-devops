# modules/vpc/variables.tf

variable "aws_region" {
  description = "AWS 리전 (예: ap-northeast-2)"
  type        = string
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 태깅 및 이름에 사용)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (리소스 태깅 및 이름에 사용)"
  type        = string
}

variable "common_tags" {
  description = "모든 리소스에 공통적으로 적용될 태그"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr_block" {
  description = "VPC에 할당할 CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "리소스를 배포할 단일 가용 영역 (예: ap-northeast-2a)"
  type        = string
}

variable "public_subnet_cidr" {
  description = "퍼블릭 서브넷에 할당할 CIDR 블록"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_app_cidr" {
  description = "FastAPI 앱 서버용 프라이빗 서브넷 CIDR 블록"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_db_cidr" {
  description = "RDS DB용 프라이빗 서브넷 CIDR 블록"
  type        = string
  default     = "10.0.3.0/24"
}
