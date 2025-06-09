# modules/nat_instance/variables.tf

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

variable "public_subnet_id" {
  description = "NAT 인스턴스가 배포될 퍼블릭 서브넷의 ID"
  type        = string
}

variable "vpc_id" {
  description = "NAT 인스턴스의 보안 그룹이 생성될 VPC의 ID"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "NAT 인스턴스에 접근해야 하는 프라이빗 서브넷 CIDR 블록 목록"
  type        = list(string)
  # 예시: ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "nat_instance_type" {
  description = "NAT 인스턴스로 사용할 EC2 인스턴스 유형"
  type        = string
  default     = "t2.micro" # 프리티어 활용
}

variable "nat_instance_ami_owner" {
  description = "NAT 인스턴스 AMI 소유자 (Amazon Linux 2의 경우 'amazon')"
  type        = string
  default     = "amazon"
}

variable "nat_instance_ami_name_filter" {
  description = "NAT 인스턴스 AMI 이름 필터 (Amazon Linux 2 최신 버전)"
  type        = string
  default     = "amzn2-ami-hvm-*-x86_64-gp2"
}

variable "admin_app_port" {
  description = "NAT 인스턴스에서 실행될 관리자 앱이 사용할 포트"
  type        = number
  default     = 8501 # 예시 포트
}

variable "admin_app_source_cidrs" {
  description = "관리자 앱에 접속을 허용할 소스 IP CIDR 블록 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"] # ☢️ 보안 경고: 실제 운영 시에는 사무실 IP 등 특정 IP 대역으로 반드시 제한하세요!
}