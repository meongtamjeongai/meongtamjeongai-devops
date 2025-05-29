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
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.module_tags, {
    Name = "${var.project_name}-public-subnet-${var.availability_zone}-${var.environment}"
    Tier = "Public"
    AZ   = var.availability_zone
  })
}

# 2-2. 프라이빗 서브넷 (FastAPI 애플리케이션 서버용)
resource "aws_subnet" "private_app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_app_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = merge(local.module_tags, {
    Name  = "${var.project_name}-private-app-subnet-${var.availability_zone}-${var.environment}"
    Tier  = "Private"
    AZ    = var.availability_zone
    Usage = "Application"
  })
}

# 2-3. 프라이빗 서브넷 (RDS 데이터베이스용)
resource "aws_subnet" "private_db" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_db_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = merge(local.module_tags, {
    Name  = "${var.project_name}-private-db-subnet-${var.availability_zone}-${var.environment}"
    Tier  = "Private"
    AZ    = var.availability_zone
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

# 4. 퍼블릭 라우트 테이블 생성 및 설정
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

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
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

resource "aws_route_table_association" "private_db" {
  subnet_id      = aws_subnet.private_db.id
  route_table_id = aws_route_table.private_db.id
}
