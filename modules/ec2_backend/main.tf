# modules/ec2_backend/main.tf

locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "ec2-backend"
  })

  # User Data 렌더링 시 사용할 변수 맵 (플레이스홀더 이름 변경 및 host_app_port 추가)
  user_data_template_vars = {
    fastapi_docker_image_placeholder    = var.fastapi_docker_image
    container_internal_port_placeholder = var.fastapi_app_port # 컨테이너 내부 포트
    host_exposed_port_placeholder       = var.host_app_port    # 호스트에 노출될 포트
  }
}

# 1. IAM 역할 및 인스턴스 프로파일 생성 (EC2 인스턴스용)
resource "aws_iam_role" "ec2_backend_role" {
  name = "${var.project_name}-ec2-backend-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.module_tags
}

# EC2 인스턴스에 SSM 접근 및 CloudWatch Logs 기본 권한을 위한 정책 연결 (선택 사항)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_backend_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent 사용 계획이 있다면 아래 정책도 연결 가능
# resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
#   role       = aws_iam_role.ec2_backend_role.name
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
# }

resource "aws_iam_instance_profile" "ec2_backend_profile" {
  name = "${var.project_name}-ec2-backend-profile-${var.environment}"
  role = aws_iam_role.ec2_backend_role.name

  tags = local.module_tags
}

# 2. EC2 백엔드 인스턴스용 보안 그룹
resource "aws_security_group" "ec2_backend_sg" {
  name        = "${var.project_name}-ec2-backend-sg-${var.environment}"
  description = "Security group for EC2 backend instances"
  vpc_id      = var.vpc_id

  # 인바운드 규칙:
  # 💥 중요: ALB로부터의 트래픽 허용 규칙은 루트 모듈에서 aws_security_group_rule을 사용하여 추가합니다.
  # ingress {
  #   description     = "Allow HTTP traffic on app port from within VPC (placeholder for ALB)"
  #   from_port       = var.fastapi_app_port
  #   to_port         = var.fastapi_app_port
  #   protocol        = "tcp"
  #   cidr_blocks     = ["0.0.0.0/0"] # 👈 이 임시 규칙 제거!
  # }

  # SSH 접근 허용 (디버깅용, var.ssh_key_name이 제공된 경우)
  dynamic "ingress" {
    for_each = var.ssh_key_name != null ? [1] : []
    content {
      description = "Allow SSH from my IP for debugging"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.my_ip_for_ssh] # 루트에서 전달받은 my_ip_for_ssh 사용
    }
  }

  # 아웃바운드 규칙: 모든 외부 트래픽 허용 (NAT 인스턴스를 통해 인터넷 접근)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.module_tags
}

# 3. 시작 템플릿 (Launch Template) 생성
resource "aws_launch_template" "ec2_backend_lt" {
  name_prefix   = "${var.project_name}-backend-lt-${var.environment}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name # var.ssh_key_name이 null이면 무시됨

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_backend_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = false # 프라이빗 서브넷에 배포
    security_groups             = [aws_security_group.ec2_backend_sg.id]
    # delete_on_termination = true # 기본값 true
  }

  # User Data 스크립트 파일 렌더링 및 Base64 인코딩
  user_data = base64encode(templatefile("${path.module}/user_data.sh", local.user_data_template_vars))

  # 인스턴스에 적용될 태그
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.module_tags, {
      Name = "${var.project_name}-backend-instance-${var.environment}"
    })
  }
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.module_tags, {
      Name = "${var.project_name}-backend-volume-${var.environment}"
    })
  }

  # Metadata 옵션 (IMDSv2 권장)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 사용
    http_put_response_hop_limit = 1
  }

  # 기본적으로 최신 버전의 시작 템플릿을 사용하도록 설정
  # update_default_version = true # 필요에 따라 사용
  # default_version = version # 특정 버전을 기본으로 지정할 때

  lifecycle {
    create_before_destroy = true
  }

  tags = local.module_tags
}

# 4. Auto Scaling Group (ASG) 생성
resource "aws_autoscaling_group" "ec2_backend_asg" {
  name_prefix = "${var.project_name}-backend-asg-${var.environment}-"

  launch_template {
    id      = aws_launch_template.ec2_backend_lt.id
    version = "$Latest" # 항상 최신 버전의 시작 템플릿 사용
  }

  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = var.private_app_subnet_ids # 프라이빗 앱 서브넷 ID 목록
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  # 🎯 ALB 대상 그룹에 ASG 인스턴스 자동 등록
  target_group_arns = var.target_group_arns # 입력받은 대상 그룹 ARN 목록 사용

  # 인스턴스 종료 정책 (기본값 또는 필요에 따라 설정)
  # termination_policies = ["Default"]

  # ASG가 생성하는 인스턴스에 자동으로 태그 전파
  # Terraform 태그와 ASG 자체 태그를 합쳐서 인스턴스에 적용
  dynamic "tag" {
    for_each = merge(local.module_tags, {
      Name                 = "${var.project_name}-backend-instance-${var.environment}"
      "AmazonEC2CreatedBy" = "TerraformASG"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  # 서비스 연결 역할 (Service-Linked Role) - ASG가 특정 작업을 수행하기 위해 필요
  # 보통 처음 ASG 생성 시 AWS가 자동으로 만들어주지만, 명시적으로 의존성을 표현할 수도 있습니다.
  # depends_on = [aws_iam_role.ec2_backend_role] # 예시
}
