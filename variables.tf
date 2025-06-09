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
  description = "데이터베이스 마스터 사용자 암호"
  type        = string
  sensitive   = true
}

variable "fastapi_secret_key" {
  description = "FastAPI 애플리케이션의 JWT 시크릿 키"
  type        = string
  sensitive   = true
}

variable "firebase_b64_json" {
  description = "Base64로 인코딩된 Firebase 서비스 계정 JSON"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The primary domain name for which the SSL certificate will be issued (e.g., 'example.com'). This will also be used as the Cloudflare zone name if not overridden."
  type        = string
  # 이 값은 Terraform Cloud 변수를 통해 주입됩니다.
}

variable "subdomain_for_cert" {
  description = "Optional subdomain to include in the certificate as a Subject Alternative Name (e.g., 'www', 'api'). If empty, only the primary_domain_name is used."
  type        = string
  default     = "www" # 기본적으로 www.domain_name 을 SAN으로 포함
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare Zone ID corresponding to your domain_name. This is required for DNS validation of the ACM certificate."
  type        = string
  # 이 값은 Terraform Cloud 변수(민감 정보일 수 있음)를 통해 주입됩니다.
}
