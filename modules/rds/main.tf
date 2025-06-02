# modules/rds/main.tf

locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "rds"
  })

  # DB 엔진에 따른 기본 포트 설정 (var.db_port가 null일 경우)
  # aws_db_instance 리소스 자체도 엔진에 따라 기본 포트를 잘 설정하지만,
  # 보안 그룹 등에서 명시적으로 사용하기 위해 정의합니다.
  db_engine_default_port = var.db_port != null ? var.db_port : (
    var.db_engine == "postgres" ? 5432 : (
      var.db_engine == "mysql" ? 3306 : null # 다른 엔진 지원 시 추가
      # 지원하지 않는 엔진이거나 var.db_port도 null이면, 실제 DB 생성 시 엔진 기본값에 의존
  ))
}

# 1. DB 서브넷 그룹 생성
# RDS 인스턴스가 위치할 프라이빗 서브넷들의 그룹입니다.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-rds-sng-${var.environment}"
  subnet_ids = var.db_subnet_ids # 루트 모듈에서 전달받은 프라이빗 DB 서브넷 ID 목록

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-rds-sng-${var.environment}"
  })
}

# 2. RDS 인스턴스용 보안 그룹 생성
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg-${var.environment}"
  description = "Security group for RDS instance, allowing access from backend EC2 instances"
  vpc_id      = var.vpc_id

  # 인바운드 규칙: 백엔드 EC2 인스턴스 보안 그룹으로부터 DB 포트로의 접근 허용
  ingress {
    description     = "Allow DB traffic from Backend EC2 SG"
    from_port       = local.db_engine_default_port # 계산된 DB 포트
    to_port         = local.db_engine_default_port # 계산된 DB 포트
    protocol        = "tcp"
    security_groups = [var.backend_ec2_sg_id] # 백엔드 EC2의 보안 그룹 ID
  }

  # 아웃바운드 규칙: 일반적으로 모든 아웃바운드를 허용 (필요에 따라 제한 가능)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-rds-sg-${var.environment}"
  })
}

# 3. RDS DB 인스턴스 생성
resource "aws_db_instance" "main" {
  identifier_prefix = "${lower(var.project_name)}-rds-${lower(var.environment)}-" # 최종 식별자는 AWS가 유니크하게 생성

  engine            = var.db_engine
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = var.db_storage_type
  storage_encrypted = var.storage_encrypted # 기본값 true 권장

  db_name  = var.db_name # 초기 데이터베이스 이름 (엔진에 따라 생성되지 않을 수도 있음)
  username = var.db_username
  password = var.db_password              # sensitive = true 로 선언된 변수
  port     = local.db_engine_default_port # 명시적으로 포트 지정

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  multi_az            = var.multi_az            # 프리티어는 보통 false
  publicly_accessible = var.publicly_accessible # 보안상 false 권장

  backup_retention_period = var.backup_retention_period # 자동 백업 보존 기간
  skip_final_snapshot     = var.skip_final_snapshot     # 개발/테스트 시 true

  # Character Set, Timezone 등 파라미터 그룹을 통해 설정 가능 (여기서는 기본값 사용)
  # parameter_group_name = aws_db_parameter_group.default.name 

  # 유지보수 기간, 백업 기간 등 설정 가능
  # maintenance_window      = "sun:03:00-sun:04:00" 
  # backup_window           = "04:00-05:00"

  # CloudWatch Logs 로 로그 내보내기 (선택 사항)
  # enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"] # PostgreSQL 예시

  apply_immediately = false # 변경 사항을 다음 유지보수 기간에 적용 (운영 환경 고려)
  # 개발 중에는 true로 설정하여 즉시 적용되도록 할 수도 있음

  deletion_protection = var.deletion_protection # 운영 환경에서는 true 권장

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-rds-instance-${var.environment}"
  })
}
