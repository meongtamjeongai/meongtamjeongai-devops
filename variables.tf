# ==============================================================================
# Ⅰ. 기본 프로젝트 설정 (Project & Environment)
# ==============================================================================

variable "project_name" {
  description = "프로젝트의 이름으로, 각종 리소스 태그에 사용됩니다."
  type        = string
  default     = "fastapi-infra"
}

variable "environment" {
  description = "배포 환경을 구분하기 위한 값입니다. (예: dev, stg, prod)"
  type        = string
  default     = "dev"
}

# ==============================================================================
# Ⅱ. AWS 리전 및 가용 영역 (Region & Availability Zones)
# ==============================================================================

variable "aws_region" {
  description = "AWS 리소스를 배포할 리전입니다."
  type        = string
  default     = "ap-northeast-2"
}

variable "availability_zones" {
  description = "리소스를 배포할 가용 영역 목록입니다. (최소 2개 권장)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"] # 서울 리전 예시
}

# ==============================================================================
# Ⅲ. 네트워크 설정 (Networking)
# ==============================================================================

variable "vpc_cidr_block" {
  description = "VPC에 할당할 CIDR 블록입니다."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "각 가용 영역에 생성할 퍼블릭 서브넷의 CIDR 블록 목록입니다."
  type        = list(string)
  default     = ["10.0.100.0/24", "10.0.101.0/24"]
}

variable "private_subnet_app_cidr" {
  description = "FastAPI 애플리케이션 서버를 위한 프라이빗 서브넷의 CIDR 블록입니다."
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_db_subnet_cidrs" {
  description = "각 가용 영역에 생성할 데이터베이스용 프라이빗 서브넷의 CIDR 블록 목록입니다."
  type        = list(string)
  default     = ["10.0.30.0/24", "10.0.103.0/24"]
}

# ==============================================================================
# Ⅳ. 애플리케이션 및 인스턴스 설정 (Application & Instance)
# ==============================================================================

variable "custom_fastapi_docker_image" {
  description = "ECR 리포지토리가 비어있을 경우 사용할 대체(Fallback) Docker 이미지 URI입니다."
  type        = string
  default     = "tiangolo/uvicorn-gunicorn-fastapi:python3.9"
}

variable "backend_app_port" {
  description = "EC2 인스턴스 내부에서 실행되는 백엔드 애플리케이션의 포트입니다."
  type        = number
  default     = 80
}

variable "nat_instance_ami_id_override" {
  description = "NAT 인스턴스에 사용할 특정 AMI ID입니다. 비워두면 최신 Amazon Linux 2 AMI를 찾습니다."
  type        = string
  default     = "ami-03761804003d15fb2" # 필요시 특정 AMI로 고정
}

variable "admin_app_port" {
  description = "NAT 인스턴스에서 실행될 관리자 도구(예: Streamlit)가 사용할 포트입니다."
  type        = number
  default     = 8501
}

# ==============================================================================
# Ⅴ. 도메인 및 인증서 (Domain & Certificate)
# ==============================================================================

variable "domain_name" {
  description = "ACM 인증서를 발급할 기본 도메인 이름입니다. (예: example.com)"
  type        = string
  # Terraform Cloud/Enterprise 또는 tfvars 파일을 통해 주입되어야 합니다.
}

variable "subdomain_for_cert" {
  description = "인증서의 주체 대체 이름(SAN)에 포함할 하위 도메인입니다. (예: www, api)"
  type        = string
  default     = "www"
}

variable "cloudflare_zone_id" {
  description = "ACM 인증서의 DNS 검증에 필요한 Cloudflare Zone ID입니다."
  type        = string
  # Terraform Cloud/Enterprise 또는 tfvars 파일을 통해 주입되어야 합니다.
}

# ==============================================================================
# Ⅵ. 민감 정보 및 외부 서비스 키 (Secrets & API Keys)
# ==============================================================================

variable "db_password" {
  description = "데이터베이스 마스터 사용자의 암호입니다."
  type        = string
  sensitive   = true
}

variable "fastapi_secret_key" {
  description = "FastAPI 애플리케이션의 JWT(JSON Web Token) 시크릿 키입니다."
  type        = string
  sensitive   = true
}

variable "firebase_b64_json" {
  description = "Base64로 인코딩된 Firebase 서비스 계정 JSON 파일 내용입니다."
  type        = string
  sensitive   = true
}

variable "gemini_api_key" {
  description = "Google Gemini API를 사용하기 위한 키입니다."
  type        = string
  sensitive   = true
}