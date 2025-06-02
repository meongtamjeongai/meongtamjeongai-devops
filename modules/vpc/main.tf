# modules/vpc/main.tf

# 모듈 내 리소스에 공통적으로 적용될 태그를 위한 local 변수
locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "vpc"
    Name            = "${var.project_name}-vpc-${var.environment}"
  })
}

# 1. Virtual Private Cloud (VPC) 생성
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-vpc-${var.environment}"
  })
}

# 2. 서브넷 생성
# 2-1. 퍼블릭 서브넷
resource "aws_subnet" "public" {

  for_each = {
    for i, az in var.availability_zones : i => {
      az   = az
      cidr = var.public_subnet_cidrs[i]
    }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-public-subnet-${each.value.az}-${var.environment}"
    Tier = "Public"
    AZ   = each.value.az
  })
}

# 2-2. 프라이빗 서브넷 (FastAPI 애플리케이션 서버용)
resource "aws_subnet" "private_db" {
  for_each = {
    for i, az in var.availability_zones : i => { # public 서브넷과 동일한 AZ 목록 사용
      az   = az
      cidr = var.private_db_subnet_cidrs[i] # DB용 CIDR 목록 사용
    }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az # 👈 실제 서브넷이 생성될 AZ
  map_public_ip_on_launch = false

  tags = merge(local.module_tags, {
    Name  = "${var.project_name}-private-db-subnet-${each.value.az}-${var.environment}"
    Tier  = "Private"
    AZ    = each.value.az
    Usage = "Database"
  })
}

# 3. 인터넷 게이트웨이 (IGW) 생성 및 VPC에 연결
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-igw-${var.environment}"
  })
}

# 4. 퍼블릭 라우트 테이블 생성 및 설정 (모든 퍼블릭 서브넷에 동일한 라우트 테이블 연결)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-public-rt-${var.environment}"
    Tier = "Public"
  })
}

# 생성된 모든 퍼블릭 서브넷에 위 라우트 테이블 연결
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public # aws_subnet.public이 for_each로 생성되므로, association도 for_each 사용
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# 6. 프라이빗 라우트 테이블 생성 (⚠️ 중요: 0.0.0.0/0 라우팅 규칙은 여기서 제거)
# 6-1. 프라이빗 서브넷(App)용 라우트 테이블
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.module_tags, {
    Name  = "${var.project_name}-private-app-rt-${var.environment}"
    Tier  = "Private"
    Usage = "Application"
  })
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = aws_subnet.private_app.id
  route_table_id = aws_route_table.private_app.id
}

# 6-2. 프라이빗 서브넷(DB)용 라우트 테이블
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.module_tags, {
    Name  = "${var.project_name}-private-db-rt-${var.environment}"
    Tier  = "Private"
    Usage = "Database"
  })
}

# 프라이빗 DB 서브넷들에 대한 라우트 테이블 연결(association)도 for_each를 사용해야 합니다.
# 예를 들어, 모든 DB 서브넷이 동일한 (NAT로 향하는) 프라이빗 라우트 테이블을 사용한다면:
resource "aws_route_table_association" "private_db" {
  for_each       = aws_subnet.private_db # aws_subnet.private_db가 for_each로 생성되므로
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id # private_db_rt 를 참조 (이름 확인 필요, 예시임)
  # 또는 각 AZ별로 별도의 라우트 테이블을 가질 수도 있음
}
