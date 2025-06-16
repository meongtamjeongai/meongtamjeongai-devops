# modules/rds/variables.tf

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
  description = "RDS 인스턴스의 보안 그룹이 생성될 VPC ID"
  type        = string
}

variable "db_subnet_ids" {
  description = "RDS 인스턴스를 배포할 프라이빗 DB 서브넷 ID 목록"
  type        = list(string)
}

variable "db_engine" {
  description = "데이터베이스 엔진 (예: postgres, mysql, oracle-se2, sqlserver-ex)"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "데이터베이스 엔진 버전"
  type        = string
  # 엔진에 따라 유효한 버전을 AWS 설명서에서 확인해야 합니다.
  default = "17.4"
}

variable "db_instance_class" {
  description = "RDS 인스턴스 유형 (프리티어: db.t3.micro 또는 db.t4g.micro - 리전/엔진별 지원 확인)"
  type        = string
  default     = "db.t4g.micro" # PostgreSQL 프리티어 가능 (20GB 스토리지와 함께)
}

variable "db_allocated_storage" {
  description = "할당된 스토리지 크기 (GB, 프리티어: 20GB)"
  type        = number
  default     = 20
}

variable "db_storage_type" {
  description = "스토리지 유형 (gp2, gp3, io1 등)"
  type        = string
  default     = "gp2" # 프리티어에서는 일반 SSD (gp2) 사용
}

variable "db_name" {
  description = "생성할 데이터베이스의 초기 이름 (DB 식별자 아님)"
  type        = string
  default     = "fastapidb" # 예시
}

variable "db_username" {
  description = "데이터베이스 마스터 사용자 이름"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "데이터베이스 마스터 사용자 암호 (매우 민감한 정보!)"
  type        = string
  sensitive   = true # Terraform 출력에 표시되지 않도록 함
  # 이 값은 Terraform Cloud 변수(민감) 또는 AWS Secrets Manager를 통해 관리하는 것이 가장 좋습니다.
  # 루트 모듈에서 값을 전달받아야 합니다.
}

variable "multi_az" {
  description = "다중 AZ 배포 여부 (프리티어에서는 보통 false)"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "RDS 인스턴스에 공인 IP 할당 여부 (보안상 false 권장)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "DB 인스턴스 삭제 시 최종 스냅샷 생성 여부 (개발/테스트 시 true)"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "자동 백업 보존 기간 (일, 0이면 비활성화, 프리티어는 7일 가능)"
  type        = number
  default     = 7 # 개발/테스트용으로 비활성화, 필요시 7 이상으로 설정
}

variable "storage_encrypted" {
  description = "스토리지 암호화 사용 여부"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "삭제 방지 기능 활성화 여부 (운영 환경에서는 true 권장)"
  type        = bool
  default     = false # 개발/테스트용
}

variable "db_port" {
  description = "데이터베이스 엔진 포트 (이 변수는 직접 사용되기보다 내부적으로 엔진에 따라 결정됨)"
  type        = number
  default     = null # null로 두면 엔진 기본 포트 사용 (PostgreSQL: 5432, MySQL: 3306)
}
