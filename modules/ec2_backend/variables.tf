# modules/ec2_backend/variables.tf

variable "project_name" {
  description = "프로젝트 이름 (리소스 태깅 및 이름에 사용)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전 (ECR 로그인 등에 사용)"
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

variable "vpc_id" {
  description = "EC2 인스턴스의 보안 그룹이 생성될 VPC ID"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "EC2 인스턴스(ASG)를 배포할 프라이빗 앱 서브넷 ID 목록"
  type        = list(string) # 여러 AZ에 걸쳐 배포할 경우를 대비해 list로 받음 (현재는 단일 AZ)
}

variable "instance_type" {
  description = "EC2 인스턴스 유형"
  type        = string
  default     = "t2.micro" # 프리티어
}

variable "ami_id" {
  description = "EC2 인스턴스에 사용할 AMI ID (Amazon Linux 2 권장)"
  type        = string
  # 이 값은 루트 모듈에서 data.aws_ami를 통해 동적으로 가져와 전달하는 것이 좋습니다.
}

# Auto Scaling Group (ASG) 관련 변수
variable "asg_min_size" {
  description = "ASG의 최소 인스턴스 수"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "ASG의 최대 인스턴스 수"
  type        = number
  default     = 2 # 테스트를 위해 2로 설정, 필요시 조정
}

variable "asg_desired_capacity" {
  description = "ASG의 원하는 인스턴스 수"
  type        = number
  default     = 1
}

variable "health_check_type" {
  description = "ASG 헬스 체크 유형 (EC2 또는 ELB)"
  type        = string
  default     = "ELB"
}

variable "asg_instance_warmup" {
  description = "인스턴스 새로 고침 시 새 인스턴스가 서비스에 투입되기 전 준비 시간 (초)"
  type        = number
  default     = 30
}

variable "asg_min_healthy_percentage" {
  description = "인스턴스 새로 고침 중 유지되어야 하는 최소 정상 인스턴스 비율 (%)"
  type        = number
  default     = 100 # 예: 90%. 가용성을 위해 적절히 조절
}

# (선택 사항) 인스턴스 새로 고침 체크포인트 관련 변수 (기본값은 null로 사용 안 함)
variable "asg_refresh_checkpoint_percentages" {
  description = "인스턴스 새로 고침을 일시 중지할 체크포인트 비율 목록 (예: [30, 60, 100])"
  type        = list(number)
  default     = null
}

variable "asg_refresh_checkpoint_delay" {
  description = "각 체크포인트에서 대기할 시간 (ISO 8601 기간 형식, 예: PT5M = 5분)"
  type        = string
  default     = null
}

variable "health_check_grace_period" {
  description = "새 인스턴스 시작 후 헬스 체크 유예 기간(초)"
  type        = number
  default     = 60
}

# Docker 및 FastAPI 관련 변수
variable "fastapi_docker_image" {
  description = "실행할 FastAPI 애플리케이션의 Docker 이미지 (예: your-account/your-repo:latest)"
  type        = string
}

variable "fastapi_app_port" {
  description = "FastAPI 애플리케이션이 컨테이너 내부에서 실행되는 포트"
  type        = number
  default     = 80 # 위 예제 이미지는 80 포트에서 실행됨
}

variable "host_app_port" { # 👈 새로 추가: 컨테이너를 호스트에 노출할 포트
  description = "EC2 호스트에서 Docker 컨테이너의 애플리케이션을 노출할 포트 (ALB가 이 포트를 타겟)"
  type        = number
  default     = 80
}

variable "my_ip_for_ssh" {
  description = "EC2 인스턴스에 SSH 접근을 허용할 나의 IP 주소 (CIDR 형태, 디버깅용)"
  type        = string
  default     = "0.0.0.0/0" # ☢️ 보안 경고: 실제 IP로 변경 권장!
}

variable "target_group_arns" {
  description = "EC2 인스턴스를 등록할 ALB 대상 그룹 ARN 목록"
  type        = list(string)
  default     = [] # 기본값은 빈 리스트
}

variable "backend_app_port" {
  description = "백엔드 애플리케이션이 EC2 인스턴스에서 사용하는 포트 (ALB 대상 그룹 및 보안 그룹 규칙에 사용)"
  type        = number
  default     = 80 # ec2_backend 모듈의 user_data.sh 에서 호스트의 80 포트로 매핑했음
}

variable "fastapi_database_url" {
  description = "FastAPI가 사용할 전체 DATABASE_URL"
  type        = string
  sensitive   = true # DB 연결 정보는 민감 정보이므로 출력에 노출되지 않도록 함
}

variable "fastapi_secret_key" {
  description = "FastAPI 애플리케이션의 JWT 시크릿 키"
  type        = string
  sensitive   = true # 시크릿 키는 민감 정보
}

variable "firebase_b64_json" {
  description = "Base64로 인코딩된 Firebase 서비스 계정 JSON"
  type        = string
  sensitive   = true # 서비스 계정 키는 민감 정보
}

variable "fastapi_gemini_api_key" {
  description = "Google Gemini API Key for the FastAPI application"
  type        = string
  sensitive   = true
}