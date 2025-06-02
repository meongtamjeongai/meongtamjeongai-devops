# terraform-aws-fastapi-infra/variables.tf

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

variable "availability_zone" {
  description = "리소스를 배포할 단일 가용 영역 (예: ap-northeast-2a)"
  type        = string
  default     = "ap-northeast-2a"
}

# VPC 및 NAT Instance 모듈에서 사용할 CIDR 변수들
variable "vpc_cidr_block" {
  description = "VPC에 할당할 CIDR 블록"
  type        = string
  default     = "10.0.0.0/16" # VPC 모듈의 기본값과 동일하게 설정하거나 필요시 수정
}

variable "public_subnet_cidr" {
  description = "퍼블릭 서브넷에 할당할 CIDR 블록"
  type        = string
  default     = "10.0.1.0/24" # VPC 모듈의 기본값과 동일하게 설정하거나 필요시 수정
}

variable "private_subnet_app_cidr" {
  description = "FastAPI 앱 서버용 프라이빗 서브넷 CIDR 블록"
  type        = string
  default     = "10.0.2.0/24" # VPC 모듈의 기본값과 동일하게 설정하거나 필요시 수정
}

variable "private_subnet_db_cidr" {
  description = "RDS DB용 프라이빗 서브넷 CIDR 블록"
  type        = string
  default     = "10.0.3.0/24" # VPC 모듈의 기본값과 동일하게 설정하거나 필요시 수정
}

# NAT 인스턴스 접속용 변수
variable "ssh_key_name" {
  description = "NAT 인스턴스에 연결할 EC2 키 페어 이름 (선택 사항, 없으면 null)"
  type        = string
  default     = "meongtamjeongai"
}

variable "my_ip_for_ssh" {
  description = "NAT 인스턴스 SSH 접근을 허용할 나의 IP 주소 (CIDR 형태)"
  type        = string
  default     = "0.0.0.0/0" # ☢️ 보안 경고: 실제 IP로 반드시 변경하세요!
}

variable "backend_app_port" {
  description = "백엔드 애플리케이션이 EC2 인스턴스에서 사용하는 포트 (ALB 대상 그룹 및 보안 그룹 규칙에 사용)"
  type        = number
  default     = 80 # ec2_backend 모듈의 user_data.sh 에서 호스트의 80 포트로 매핑했음
}
