# terraform-aws-fastapi-infra/variables.tf

variable "custom_fastapi_docker_image" {
  description = "배포할 사용자 정의 FastAPI 애플리케이션 Docker 이미지 URI"
  type        = string
  default     = "tiangolo/uvicorn-gunicorn-fastapi:python3.9" # 기본값 또는 이전 버전 이미지
}

variable "aws_region" {
  description = "AWS 리소스를 배포할 리전입니다."
  type        = string
  default     = "ap-northeast-2"
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

variable "availability_zones" {
  description = "리소스를 배포할 가용 영역 목록 (최소 2개 권장)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"] # 예시: 서울 리전의 a, c 영역
}

# VPC 및 NAT Instance 모듈에서 사용할 CIDR 변수들
variable "vpc_cidr_block" {
  description = "VPC에 할당할 CIDR 블록"
  type        = string
  default     = "10.0.0.0/16" # VPC 모듈의 기본값과 동일하게 설정하거나 필요시 수정
}

variable "public_subnet_cidrs" {
  description = "각 가용 영역에 생성할 퍼블릭 서브넷 CIDR 블록 목록"
  type        = list(string)
  default     = ["10.0.100.0/24", "10.0.101.0/24"] # 예시: 2개의 CIDR 블록
}

variable "private_subnet_app_cidr" {
  description = "FastAPI 앱 서버용 프라이빗 서브넷 CIDR 블록"
  type        = string
  default     = "10.0.2.0/24" # VPC 모듈의 기본값과 동일하게 설정하거나 필요시 수정
}

variable "private_db_subnet_cidrs" { # 👈 리스트 형태로 변경 또는 신규 추가
  description = "각 가용 영역에 생성할 프라이빗 DB 서브넷 CIDR 블록 목록"
  type        = list(string)
  default     = ["10.0.30.0/24", "10.0.103.0/24"] # 예시: 2개의 CIDR 블록 (public_subnet_cidrs와 겹치지 않게)
}

# NAT 인스턴스 접속용 변수

variable "backend_app_port" {
  description = "백엔드 애플리케이션이 EC2 인스턴스에서 사용하는 포트"
  type        = number
  default     = 80
}

variable "db_password" {
  description = "데이터베이스 마스터 사용자 암호 (매우 민감한 정보!)"
  type        = string
  sensitive   = true # Terraform 출력에 표시되지 않도록 함
  # 이 값은 Terraform Cloud 변수(민감) 또는 AWS Secrets Manager를 통해 관리하는 것이 가장 좋습니다.
  # 루트 모듈에서 값을 전달받아야 합니다.
}
