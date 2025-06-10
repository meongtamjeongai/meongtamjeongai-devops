# modules/alb/main.tf

locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "alb"
  })
}

# -----------------------------------------------------------------------------
# 1. ALB용 보안 그룹 생성
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # 인바운드 규칙: 외부 인터넷에서 오는 HTTP(80), HTTPS(443) 트래픽 허용
  ingress {
    description      = "Allow HTTP traffic from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  dynamic "ingress" {
    for_each = var.create_https_listener ? [1] : []
    content {
      description      = "Allow HTTPS traffic from anywhere"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # 아웃바운드 규칙: 모든 대상(EC2, NAT)으로 트래픽을 보낼 수 있도록 허용
  egress {
    description = "Allow all outbound traffic from ALB to any destination"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.module_tags
}

# -----------------------------------------------------------------------------
# 2. Application Load Balancer (ALB) 생성
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = var.alb_is_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  tags                       = local.module_tags
}

# -----------------------------------------------------------------------------
# 3. 대상 그룹 (Target Groups) 생성
# -----------------------------------------------------------------------------

# 3-1. FastAPI 앱용 대상 그룹 (기존 'main'에서 이름 변경)
resource "aws_lb_target_group" "fastapi_app" {
  name        = "${var.project_name}-${var.environment}-tg-fastapi"
  port        = var.backend_app_port # FastAPI 앱 포트 (예: 80)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.module_tags, { Purpose = "FastAPI-App-Target" })
}

# 3-2. 관리자 앱용 대상 그룹 (새로 추가)
resource "aws_lb_target_group" "admin_app" {
  count = var.create_admin_target_group ? 1 : 0

  name        = "${var.project_name}-${var.environment}-tg-admin"
  port        = var.admin_app_port # 관리자 앱 포트 (예: 8501)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled  = true
    path     = "/" # 관리자 앱의 헬스체크 경로
    matcher  = "200-399"
    interval = 30 # 관리자 앱은 덜 중요하므로 간격을 길게 설정
    timeout  = 10
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.module_tags, { Purpose = "Admin-App-Target" })
}

# 3-3. 관리자 앱 대상 그룹에 NAT 인스턴스를 타겟으로 등록 (새로 추가)
resource "aws_lb_target_attachment" "nat_instance_attachment" {
  count = var.create_admin_target_group && var.nat_instance_id != null ? 1 : 0

  target_group_arn = aws_lb_target_group.admin_app[0].arn
  target_id        = var.nat_instance_id # 루트에서 NAT 인스턴스 ID를 받아옴
  port             = var.admin_app_port
}


# -----------------------------------------------------------------------------
# 4. ALB 리스너 및 규칙 생성
# -----------------------------------------------------------------------------

# 4-1. HTTP 리스너 (80번 포트)
# HTTPS 사용 시 모든 HTTP 요청을 HTTPS로 리디렉션하는 역할.
# HTTPS 미사용 시 트래픽을 FastAPI 앱으로 직접 포워딩.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.create_https_listener ? "redirect" : "forward"

    # HTTPS 미사용 시에만 FastAPI 앱 대상 그룹으로 포워딩
    target_group_arn = var.create_https_listener ? null : aws_lb_target_group.fastapi_app.arn

    dynamic "redirect" {
      for_each = var.create_https_listener ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# 4-2. HTTPS 리스너 (443번 포트)
# 모든 트래픽을 받아서, 규칙에 따라 분기 처리.
resource "aws_lb_listener" "https" {
  count = var.create_https_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  # 기본 동작(Default Action): 어떤 규칙과도 맞지 않는 트래픽은 FastAPI 앱으로 보냄
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fastapi_app.arn
  }
}

# 4-3. HTTPS 리스너 규칙 (새로 추가)
# 호스트 헤더가 'admin.meong.shop'인 경우, 관리자 앱 대상 그룹으로 트래픽을 보냄.
resource "aws_lb_listener_rule" "admin_host_header_rule" {
  count = var.create_admin_target_group && var.admin_app_hostname != "" && var.create_https_listener ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10 # 낮은 숫자일수록 우선순위가 높음

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin_app[0].arn
  }

  condition {
    host_header {
      values = [var.admin_app_hostname] # 예: ["admin.meong.shop"]
    }
  }
}