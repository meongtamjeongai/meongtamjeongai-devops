# modules/alb/variables.tf

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

variable "vpc_id" {
  description = "ALB 및 관련 리소스가 생성될 VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "ALB를 배포할 퍼블릭 서브넷 ID 목록 (최소 2개 AZ의 서브넷 권장)"
  type        = list(string)
  # 현재 저희 구성에서는 단일 퍼블릭 서브넷만 사용 중이지만, ALB는 보통 2개 이상의 AZ에 걸쳐 구성됩니다.
  # 루트 모듈에서 [module.vpc.public_subnet_id] 와 같이 단일 ID를 리스트로 전달할 예정입니다.
}

variable "alb_is_internal" {
  description = "ALB를 내부용(internal)으로 생성할지 여부 (false면 인터넷 연결)"
  type        = bool
  default     = false # 기본값: 인터넷 연결 ALB
}

variable "backend_app_port" {
  description = "백엔드 EC2 인스턴스에서 애플리케이션이 실행 중인 포트 (대상 그룹이 트래픽을 전달할 포트)"
  type        = number
  default     = 80 # 이전 ec2_backend 모듈의 user_data.sh에서 호스트의 80번 포트로 매핑함
}

variable "health_check_path" {
  description = "대상 그룹 헬스 체크 경로"
  type        = string
  default     = "/" # FastAPI 루트 경로 또는 별도 헬스 체크 엔드포인트
}

variable "health_check_port" {
  description = "대상 그룹 헬스 체크 포트 ('traffic-port' 또는 특정 포트)"
  type        = string
  default     = "traffic-port" # 트래픽을 받는 포트와 동일하게 사용
}

variable "health_check_protocol" {
  description = "대상 그룹 헬스 체크 프로토콜"
  type        = string
  default     = "HTTP"
}

variable "certificate_arn" {
  description = "HTTPS 리스너에 사용할 ACM 인증서 ARN (제공되지 않으면 HTTP 리스너만 생성)"
  type        = string
  default     = null
}
