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

  domain_name               = var.domain_name                                                                      # 예: "mydomain.com"
  subject_alternative_names = var.subdomain_for_cert != "" ? ["${var.subdomain_for_cert}.${var.domain_name}"] : [] # 예: ["www.mydomain.com"]
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

  private_subnet_cidrs = concat(
    [var.private_subnet_app_cidr], # 단일 앱 프라이빗 서브넷 CIDR
    var.private_db_subnet_cidrs    # DB 프라이빗 서브넷 CIDR 목록 (리스트)
  )

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

# 백엔드 EC2 인스턴스용 AMI 조회 (Amazon Linux 2): EC2 인스턴스에 사용될 AMI를 찾습니다.
data "aws_ami" "amazon_linux_2_for_backend" {
  most_recent = true
  owners      = ["amazon"] # Amazon 제공 AMI

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Amazon Linux 2 최신 HVM GP2 AMI
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ALB 모듈 호출: 애플리케이션 트래픽을 EC2 인스턴스로 분산합니다.
module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  common_tags       = local.common_tags
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids # 👈 VPC 모듈의 list 출력값 전달

  backend_app_port = var.backend_app_port # 루트의 backend_app_port -> alb의 backend_app_port로 전달

  create_https_listener = var.domain_name != "" && var.cloudflare_zone_id != ""
  certificate_arn       = module.acm.validated_certificate_arn

  # ALB는 VPC 모듈과 ACM 모듈(인증서)에 의존합니다.
  depends_on = [module.vpc, module.acm]
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
  target_group_arns          = [module.alb.target_group_arn] # module.alb가 생성된 후에 이 값이 결정됨
  health_check_type          = "ELB"                         # 명시적으로 ELB 사용
  health_check_grace_period  = 60                            # ASG 헬스 체크 유예
  asg_instance_warmup        = 30                            # 인스턴스 새로 고침 시 준비 시간
  asg_min_healthy_percentage = 100                           # 최소 정상 인스턴스 유지

  # 명확한 의존성 선언 (nat_instance 및 alb 모듈이 완료된 후 실행)
  depends_on = [module.vpc, module.nat_instance, module.alb]
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

# -----------------------------------------------------------------------------
# 3. 데이터베이스 (RDS)
# -----------------------------------------------------------------------------

# RDS 모듈 호출: 데이터베이스 인스턴스를 구성합니다.
module "rds" {
  source = "./modules/rds" # ./modules/rds 디렉토리 참조

  # 필수 입력 변수 전달
  project_name      = var.project_name
  environment       = var.environment
  common_tags       = local.common_tags
  vpc_id            = module.vpc.vpc_id                    # VPC 모듈 출력값
  db_subnet_ids     = module.vpc.private_db_subnet_ids     # VPC 모듈 출력값 (현재 단일 DB 서브넷)
  db_password       = var.db_password                      # 루트 variables.tf (Terraform Cloud에서 주입)
  backend_ec2_sg_id = module.ec2_backend.security_group_id # EC2 백엔드 모듈 출력값

  # 의존성: VPC 모듈(서브넷 ID, VPC ID)과 EC2 백엔드 모듈(보안 그룹 ID)이 완료된 후 실행
  depends_on = [module.vpc, module.ec2_backend]
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

# -----------------------------------------------------------------------------
# 5. Cloudflare DNS 레코드 생성 (ALB용 CNAME)
# -----------------------------------------------------------------------------
resource "cloudflare_dns_record" "alb_cname" {
  # var.domain_name이 설정되어 있고, ALB DNS 이름이 정상적으로 출력되었을 때만 생성
  count = var.domain_name != "" && var.cloudflare_zone_id != "" && module.alb.alb_dns_name != null ? 1 : 0

  zone_id = var.cloudflare_zone_id
  # name: Cloudflare에 등록할 레코드 이름.
  name    = var.subdomain_for_cert != "" ? var.subdomain_for_cert : var.domain_name # 또는 "@" 사용 가능
  content = module.alb.alb_dns_name                                                 # ALB 모듈에서 출력된 DNS 이름
  type    = "CNAME"
  proxied = true # Cloudflare의 CDN 및 보호 기능을 사용하려면 true (권장)
  ttl     = 1    # 1은 'Automatic'을 의미, 또는 원하는 TTL 값 (예: 300)

  # 이 리소스는 ALB가 생성된 후에 실행되어야 합니다.
  # module.alb.alb_dns_name을 참조하므로 암시적 의존성이 있지만, 명시적으로 추가할 수도 있습니다.
  depends_on = [module.alb]
}
