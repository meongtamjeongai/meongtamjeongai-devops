# terraform-aws-fastapi-infra/main.tf
#
# 이 파일은 전체 인프라 스택의 주 진입점 역할을 합니다.
# 다양한 모듈을 호출하고, 각 모듈 간의 의존성을 연결합니다.

# -----------------------------------------------------------------------------
# 0. ACM 인증서 생성 (Cloudflare DNS 검증)
# -----------------------------------------------------------------------------
module "acm" {
  source = "./modules/acm"

  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags

  domain_name               = var.domain_name
    subject_alternative_names = compact(concat(
    var.subdomain_for_cert != "" ? ["${var.subdomain_for_cert}.${var.domain_name}"] : [],
    ["admin.${var.domain_name}"] # admin 서브도메인 추가
  ))
  # 만약 여러 SAN이 필요하면, subject_alternative_names = ["www.${var.domain_name}", "api.${var.domain_name}"] 와 같이 리스트로 구성
  cloudflare_zone_id = var.cloudflare_zone_id
}

# -----------------------------------------------------------------------------
# 1. VPC 및 네트워크 인프라 (VPC, 서브넷, 라우팅 테이블, NAT 인스턴스)
# -----------------------------------------------------------------------------

# VPC 모듈 호출: 네트워크의 기반을 정의합니다.
module "vpc" {
  source = "./modules/vpc"

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags

  availability_zones        = var.availability_zones    # 👈 루트의 list(string) 변수 전달
  public_subnet_cidrs       = var.public_subnet_cidrs   # 👈 루트의 list(string) 변수 전달
  primary_availability_zone = var.availability_zones[0] # 👈 프라이빗 서브넷용 AZ (예: 리스트의 첫 번째 AZ 사용)

  # 루트 variables.tf에 정의된 CIDR 값들을 명시적으로 전달
  vpc_cidr_block          = var.vpc_cidr_block
  private_subnet_app_cidr = var.private_subnet_app_cidr
  private_db_subnet_cidrs = var.private_db_subnet_cidrs
}

# NAT 인스턴스 모듈 호출: 프라이빗 서브넷의 아웃바운드 인터넷 액세스를 제공합니다.
module "nat_instance" {
  source = "./modules/nat_instance"

  project_name     = var.project_name
  environment      = var.environment
  common_tags      = local.common_tags
  public_subnet_id = module.vpc.public_subnet_ids[0]
  vpc_id           = module.vpc.vpc_id # VPC 모듈의 출력값 사용
  nat_instance_ami_id = var.nat_instance_ami_id_override

  private_subnet_cidrs = concat(
    [var.private_subnet_app_cidr], # 단일 앱 프라이빗 서브넷 CIDR
    var.private_db_subnet_cidrs    # DB 프라이빗 서브넷 CIDR 목록 (리스트)
  )

  # admin_app_port         = 8080 # 또는 var.admin_app_port 등으로 관리
  # admin_app_source_cidrs = ["YOUR_OFFICE_IP/32", "YOUR_HOME_IP/32"] # 예시: 사무실 및 집 IP만 허용

  depends_on = [module.vpc] # VPC가 먼저 생성되도록 의존성 명시
}

# 프라이빗 라우트 테이블에 NAT 인스턴스로 향하는 라우팅 규칙 추가:
# 앱 및 DB 프라이빗 서브넷에서 외부로 나가는 트래픽을 NAT 인스턴스로 라우팅합니다.
resource "aws_route" "private_app_subnet_to_nat" {
  route_table_id         = module.vpc.private_app_route_table_id            # VPC 모듈 출력: 앱 라우트 테이블 ID
  destination_cidr_block = "0.0.0.0/0"                                      # 모든 외부 트래픽
  network_interface_id   = module.nat_instance.primary_network_interface_id # NAT 인스턴스 모듈 출력: ENI ID

  # NAT 인스턴스가 완전히 준비된 후 라우트가 추가되도록 명시적 의존성 설정 (선택적이지만 권장)
  depends_on = [module.nat_instance]
}

resource "aws_route" "private_db_subnet_to_nat" {
  route_table_id         = module.vpc.private_db_route_table_id             # VPC 모듈 출력: DB 라우트 테이블 ID
  destination_cidr_block = "0.0.0.0/0"                                      # 모든 외부 트래픽
  network_interface_id   = module.nat_instance.primary_network_interface_id # NAT 인스턴스 모듈 출력: ENI ID

  depends_on = [module.nat_instance]
}

# -----------------------------------------------------------------------------
# 2. 애플리케이션 및 로드 밸런싱 (ALB, EC2 백엔드)
# -----------------------------------------------------------------------------

# ALB 모듈 호출: 애플리케이션 트래픽을 EC2 인스턴스로 분산합니다.
module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  common_tags       = local.common_tags
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids # 👈 VPC 모듈의 list 출력값 전달

  backend_app_port = var.backend_app_port # 루트의 backend_app_port -> alb의 backend_app_port로 전달

  # 관리자 앱 라우팅 활성화
  create_admin_target_group = true
  admin_app_port            = var.admin_app_port # 루트 변수에서 전달
  nat_instance_id           = module.nat_instance.instance_id # NAT 인스턴스 ID 전달
  admin_app_hostname        = "admin.${var.domain_name}" # 호스트 이름 동적 생성

  create_https_listener = var.domain_name != "" && var.cloudflare_zone_id != ""
  certificate_arn       = module.acm.validated_certificate_arn

  # ALB는 VPC 모듈과 ACM 모듈(인증서)에 의존합니다.
  depends_on = [module.vpc, module.acm, module.nat_instance]
}

# 백엔드 EC2 인스턴스용 AMI 조회 (Amazon Linux 2)
data "aws_ami" "amazon_linux_2_for_backend" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 백엔드 모듈 호출: FastAPI 애플리케이션을 호스팅하는 EC2 인스턴스 및 ASG를 구성합니다.
module "ec2_backend" {
  source = "./modules/ec2_backend"

  project_name           = var.project_name
  environment            = var.environment
  common_tags            = local.common_tags
  vpc_id                 = module.vpc.vpc_id
  private_app_subnet_ids = [module.vpc.private_app_subnet_id]
  ami_id                 = data.aws_ami.amazon_linux_2_for_backend.id
  instance_type          = "t2.micro"  

  aws_region           = var.aws_region
  fastapi_docker_image = var.custom_fastapi_docker_image # 👈 루트 변수 값을 모듈의 입력으로 전달
  host_app_port        = var.backend_app_port            # 루트의 backend_app_port -> ec2_backend의 host_app_port로 전달
  fastapi_app_port     = 80                              # Dockerfile EXPOSE 및 CMD 포트와 일치하도록 설정 (또는 변수화)

  # 🎯 ALB 대상 그룹 ARN 전달
  target_group_arns          = [module.alb.fastapi_app_target_group_arn]
  health_check_type          = "ELB"                         # 명시적으로 ELB 사용
  health_check_grace_period  = 60                            # ASG 헬스 체크 유예
  asg_instance_warmup        = 30                            # 인스턴스 새로 고침 시 준비 시간
  asg_min_healthy_percentage = 100                           # 최소 정상 인스턴스 유지

  fastapi_database_url = "postgresql://${module.rds.db_instance_username}:${var.db_password}@${module.rds.db_instance_endpoint}/${module.rds.db_instance_name}"
  fastapi_secret_key   = var.fastapi_secret_key
  firebase_b64_json    = var.firebase_b64_json

  fastapi_gemini_api_key = var.gemini_api_key

  # S3 버킷 이름 전달: FastAPI 애플리케이션에서 이미지 업로드에 사용
  s3_bucket_name = aws_s3_bucket.image_storage.id

  # 명확한 의존성 선언
  depends_on = [module.vpc, module.nat_instance, module.alb, module.rds]
}

# ALB에서 백엔드 EC2 인스턴스로의 트래픽을 허용하는 보안 그룹 규칙 추가:
# ALB와 EC2 인스턴스 간의 통신을 허용합니다.
resource "aws_security_group_rule" "allow_alb_to_backend" {
  type                     = "ingress"
  description              = "Allow traffic from ALB to backend EC2 instances on app port"
  from_port                = var.backend_app_port # 루트의 backend_app_port 사용
  to_port                  = var.backend_app_port # 루트의 backend_app_port 사용
  protocol                 = "tcp"
  security_group_id        = module.ec2_backend.security_group_id # 대상: 백엔드 SG
  source_security_group_id = module.alb.security_group_id         # 소스: ALB SG

  # 이 규칙은 alb와 ec2_backend 모듈이 각각의 SG를 만든 후에 적용됨
  depends_on = [module.alb, module.ec2_backend]
}

resource "aws_security_group_rule" "allow_alb_to_nat_admin" {
  description = "Allow traffic from ALB to NAT instance on admin app port"
  type        = "ingress"
  from_port   = var.admin_app_port
  to_port     = var.admin_app_port
  protocol    = "tcp"

  security_group_id        = module.nat_instance.security_group_id # 대상: NAT 인스턴스 SG
  source_security_group_id = module.alb.security_group_id          # 소스: ALB SG

  depends_on = [module.alb, module.nat_instance]
}

# -----------------------------------------------------------------------------
# 3. 데이터베이스 및 스토리지 (RDS, S3)
# -----------------------------------------------------------------------------

# RDS 모듈 호출: 데이터베이스 인스턴스를 구성합니다.
module "rds" {
  source = "./modules/rds" # ./modules/rds 디렉토리 참조

  # 필수 입력 변수 전달
  project_name  = var.project_name
  environment   = var.environment
  common_tags   = local.common_tags
  vpc_id        = module.vpc.vpc_id                # VPC 모듈 출력값
  db_subnet_ids = module.vpc.private_db_subnet_ids # VPC 모듈 출력값 (현재 단일 DB 서브넷)
  db_password   = var.db_password                  # 루트 variables.tf (Terraform Cloud에서 주입)

  depends_on = [module.vpc] # VPC에만 의존하도록 변경
}

resource "aws_security_group_rule" "allow_ec2_to_rds" {
  type                     = "ingress"
  description              = "Allow traffic from Backend EC2 to RDS"
  from_port                = module.rds.db_instance_port # rds 모듈의 출력값 사용
  to_port                  = module.rds.db_instance_port # rds 모듈의 출력값 사용
  protocol                 = "tcp"
  security_group_id        = module.rds.rds_security_group_id     # 대상: RDS 보안 그룹
  source_security_group_id = module.ec2_backend.security_group_id # 소스: EC2 보안 그룹
}

# S3 버킷 생성: FastAPI 애플리케이션에서 이미지 파일을 저장합니다.
# 이 버킷은 이미지 업로드 및 다운로드에 사용됩니다.
resource "aws_s3_bucket" "image_storage" {
  # 버킷 이름은 전역적으로 고유해야 하므로, 프로젝트와 환경 이름을 조합합니다.
  bucket = "${var.project_name}-${var.environment}-images"

  tags = merge(local.common_tags, {
    Purpose = "Image storage for FastAPI application"
  })
}

# S3 버킷에 대한 퍼블릭 액세스 차단 설정: 모든 퍼블릭 액세스를 차단합니다.
resource "aws_s3_bucket_public_access_block" "image_storage_access_block" {
  bucket = aws_s3_bucket.image_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EC2 인스턴스용 S3 접근 IAM 정책 생성
# EC2 인스턴스가 이미지 버킷에 객체를 Put/Get 할 수 있도록 허용합니다.
resource "aws_iam_policy" "s3_access_for_ec2" {
  name        = "${var.project_name}-${var.environment}-s3-access-policy"
  description = "Allows EC2 instances to Put and Get objects from the image storage S3 bucket."

  # 최소 권한 원칙: 특정 버킷에 대한 PutObject, GetObject 액션만 허용
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.image_storage.arn}/*" # 버킷 내 모든 객체에 대한 권한
      }
    ]
  })
}

# 생성한 S3 접근 정책을 EC2 역할(Role)에 연결
resource "aws_iam_role_policy_attachment" "ec2_s3_access_attachment" {
  # ec2_backend 모듈의 출력값에서 역할 이름을 가져옵니다.
  # 이를 위해 ec2_backend 모듈에 'iam_role_name' 출력이 필요합니다.
  role       = module.ec2_backend.iam_role_name
  policy_arn = aws_iam_policy.s3_access_for_ec2.arn
}



# -----------------------------------------------------------------------------
# 4. 기타 서비스 (ECR)
# -----------------------------------------------------------------------------

# ECR 레포지토리 생성: FastAPI 애플리케이션의 Docker 이미지를 저장합니다.
resource "aws_ecr_repository" "fastapi_app" {
  name                 = "${var.project_name}-${var.environment}-fastapi-app" # 예: fastapi-infra-dev-fastapi-app
  image_tag_mutability = "MUTABLE"                                            # 또는 "IMMUTABLE". MUTABLE은 태그 재사용 가능, IMMUTABLE은 불가.
  # 운영 환경에서는 고유 태그에 IMMUTABLE을 권장할 수 있습니다.

  image_scanning_configuration {
    scan_on_push = true # 이미지 푸시 시 취약점 스캔 활성화
  }

  tags = merge(local.common_tags, {
    Purpose = "FastAPI Application Docker Images"
  })
}

resource "aws_ecr_repository" "admin_app" {
  # FastAPI 앱과 겹치지 않도록 고유한 이름을 지정합니다. (예: ...-admin-app)
  name                 = "${var.project_name}-${var.environment}-admin-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Purpose = "Admin Application Docker Images"
  })
}

# -----------------------------------------------------------------------------
# 5. Cloudflare DNS 레코드 생성 (ALB용 CNAME)
# -----------------------------------------------------------------------------

# 5.1. 특정 서브도메인용 CNAME (예: www.example.com)
resource "cloudflare_dns_record" "alb_subdomain_cname" {
  # var.subdomain_for_cert 비어있지 않고, 기본 조건 만족 시 생성
  #count = var.domain_name != "" && var.cloudflare_zone_id != "" && module.alb.alb_dns_name != null && var.subdomain_for_cert != "" ? 1 : 0
  count = var.domain_name != "" && var.cloudflare_zone_id != "" && var.subdomain_for_cert != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = var.subdomain_for_cert # 예: "www"
  content = module.alb.alb_dns_name
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

# Cloudflare DNS 레코드 추가 (admin.meong.shop)
resource "cloudflare_dns_record" "admin_cname" {
  count = var.domain_name != "" && var.cloudflare_zone_id != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "admin" # 서브도메인 이름
  content = module.alb.alb_dns_name # 기존 ALB를 가리킴
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

# 5.2. 루트 도메인용 CNAME (예: example.com)
resource "cloudflare_dns_record" "alb_root_cname" {
  # 기본 조건 만족 시 생성
  #count = var.domain_name != "" && var.cloudflare_zone_id != "" && module.alb.alb_dns_name != null ? 1 : 0
  count = var.domain_name != "" && var.cloudflare_zone_id != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = var.domain_name # Cloudflare에서는 루트 도메인을 나타낼 때 실제 도메인 이름 또는 "@" 사용 가능
  # 여기서는 var.domain_name 사용
  content = module.alb.alb_dns_name
  type    = "CNAME" # Cloudflare가 CNAME Flattening 처리
  proxied = true
  ttl     = 1
}

# 5.3. 와일드카드 서브도메인용 CNAME (예: *.example.com)
resource "cloudflare_dns_record" "alb_wildcard_cname" {
  # 기본 조건 만족 시 생성
  # count = var.domain_name != "" && var.cloudflare_zone_id != "" && module.alb.alb_dns_name != null ? 1 : 0
  count = var.domain_name != "" && var.cloudflare_zone_id != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "*" # 와일드카드
  content = module.alb.alb_dns_name
  type    = "CNAME"
  proxied = true
  ttl     = 1
}
