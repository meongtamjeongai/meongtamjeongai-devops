# modules/alb/main.tf

locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "alb"
  })

  # 리스너 포트 결정 (HTTPS 우선)
  listener_port     = var.certificate_arn != null ? 443 : 80
  listener_protocol = var.certificate_arn != null ? "HTTPS" : "HTTP"
}

# 1. ALB용 보안 그룹 생성
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # 인바운드 규칙:
  # HTTP 트래픽 허용 (0.0.0.0/0 : 모든 곳에서)
  ingress {
    description      = "Allow HTTP traffic from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTPS 트래픽 허용 (ACM 인증서가 제공된 경우)
  dynamic "ingress" {
    for_each = var.certificate_arn != null ? [1] : []
    content {
      description      = "Allow HTTPS traffic from anywhere"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # 아웃바운드 규칙: 백엔드 EC2 인스턴스로 트래픽 전달 허용
  egress {
    description = "Allow traffic to backend EC2 instances on app port"
    from_port   = var.backend_app_port # 백엔드 앱 포트
    to_port     = var.backend_app_port
    protocol    = "tcp"
    # 대상은 백엔드 EC2 인스턴스의 보안 그룹
    # cidr_blocks = ["0.0.0.0/0"] # 또는 더 제한적으로 설정 가능
    security_groups = [var.backend_security_group_id]
  }

  tags = local.module_tags
}

# 2. Application Load Balancer (ALB) 생성
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = var.alb_is_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids # 퍼블릭 서브넷 ID 목록

  # 삭제 보호 비활성화 (개발/테스트 환경에 적합)
  enable_deletion_protection = false

  # 접근 로그 설정 (선택 사항, 필요시 S3 버킷 생성 후 설정)
  # access_logs {
  #   bucket  = "your-alb-logs-s3-bucket-name"
  #   prefix  = "${var.project_name}-alb"
  #   enabled = true
  # }

  tags = local.module_tags
}

# 3. 대상 그룹 (Target Group) 생성
resource "aws_lb_target_group" "main" {
  name_prefix = "${var.project_name}-tg-" # 이름이 32자 제한을 넘지 않도록 prefix 사용
  port        = var.backend_app_port      # 백엔드 인스턴스의 애플리케이션 포트
  protocol    = "HTTP"                    # ALB -> 백엔드 통신 프로토콜
  vpc_id      = var.vpc_id
  target_type = "instance" # EC2 인스턴스를 대상으로 함

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = var.health_check_port
    protocol            = var.health_check_protocol
    matcher             = "200-399" # HTTP 응답 코드 200-399를 정상으로 간주
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }

  # 대상 그룹에 직접 인스턴스를 등록하지 않고, Auto Scaling Group에서 이 대상 그룹을 사용하도록 설정할 예정
  # 따라서 targets 블록은 비워둡니다.

  tags = local.module_tags
}

# 4. HTTP 리스너 생성
# (HTTPS를 기본으로 사용하고 HTTP는 HTTPS로 리디렉션할 수도 있지만, 여기서는 ACM 인증서 유무에 따라 분기)
resource "aws_lb_listener" "http" {
  # ACM 인증서가 없거나, 있더라도 HTTP 리스너를 별도로 생성하는 경우
  count = var.certificate_arn == null ? 1 : 0 # 인증서가 없으면 HTTP 리스너 생성

  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# 5. HTTPS 리스너 생성 (ACM 인증서가 제공된 경우)
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0 # 인증서가 있을 때만 HTTPS 리스너 생성

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # 권장 보안 정책
  certificate_arn   = var.certificate_arn         # ACM 인증서 ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# 만약 HTTP로 접속 시 HTTPS로 자동 리디렉션하고 싶다면,
# aws_lb_listener.http 리소스의 default_action을 다음과 같이 수정할 수 있습니다:
# (단, 이 경우 aws_lb_listener.https 리소스가 반드시 존재해야 함)
# default_action {
#   type = "redirect"
#   redirect {
#     port        = "443"
#     protocol    = "HTTPS"
#     status_code = "HTTP_301"
#   }
# }
