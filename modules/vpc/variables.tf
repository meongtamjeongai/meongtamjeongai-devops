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

variable "availability_zones" {
  description = "리소스를 배포할 가용 영역 목록"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "각 가용 영역에 생성할 퍼블릭 서브넷 CIDR 블록 목록"
  type        = list(string)
}

variable "private_subnet_app_cidr" {
  description = "FastAPI 앱 서버용 프라이빗 서브넷 CIDR 블록"
  type        = string
  default     = "10.0.2.0/24" # 👈 루트에서 값을 받도록 기본값 제거 또는 주석 처리
}

variable "private_subnet_db_cidr" {
  description = "RDS DB용 프라이빗 서브넷 CIDR 블록"
  type        = string
  default     = "10.0.3.0/24" # 👈 루트에서 값을 받도록 기본값 제거 또는 주석 처리
}

# 프라이빗 서브넷을 위한 단일 AZ 지정 변수 (기존 private_subnet_app/db가 사용할 AZ)
# 만약 프라이빗 서브넷도 Multi-AZ로 확장한다면 이 변수는 필요 없어지거나 다르게 사용될 수 있습니다.
variable "primary_availability_zone" {
  description = "주요 프라이빗 리소스(예: 현재 구성의 프라이빗 서브넷)를 배포할 단일 가용 영역"
  type        = string
  # 예: var.availability_zones[0] 값을 루트에서 전달받도록 할 수 있음
}
