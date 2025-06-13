# modules/ec2_backend/main.tf

locals {
  module_tags = merge(var.common_tags, {
    TerraformModule = "ec2-backend"
  })

  # User Data 렌더링 시 사용할 변수 맵 (플레이스홀더 이름 변경 및 host_app_port 추가)
  user_data_template_vars = {

    ecr_repository_url_placeholder = var.ecr_repository_url
    fallback_image_placeholder     = var.fallback_docker_image

    container_internal_port_placeholder = var.fastapi_app_port     # 컨테이너 내부 포트
    host_exposed_port_placeholder       = var.host_app_port        # 호스트에 노출될 포트
    aws_region_placeholder              = var.aws_region

    database_url_placeholder      = var.fastapi_database_url
    secret_key_placeholder        = var.fastapi_secret_key
    firebase_b64_json_placeholder = var.firebase_b64_json
    gemini_api_key_placeholder    = var.fastapi_gemini_api_key

    s3_bucket_name_placeholder    = var.s3_bucket_name
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

# 🎯 ECR 읽기 전용 권한 정책 연결 추가
resource "aws_iam_role_policy_attachment" "ec2_backend_ecr_ro" {
  role       = aws_iam_role.ec2_backend_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
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
  ingress {
    description = "Allow HTTP traffic on app port from within VPC (placeholder for ALB)"
    from_port   = var.host_app_port
    to_port     = var.host_app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

    # Docker 컨테이너 환경을 위해 홉 제한을 2로 설정(기본값 1, 도커 네트워크 환경 host, bridge 에 따라 조절)
    http_put_response_hop_limit = 2
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
    version = aws_launch_template.ec2_backend_lt.latest_version # 👈 항상 최신 버전의 시작 템플릿을 사용하도록 설정
  }

  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = var.private_app_subnet_ids
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  target_group_arns         = var.target_group_arns

  # 인스턴스 교체를 자동으로 수행하지 않도록 설정 (수동으로 관리)
  # 이 설정은 인스턴스가 비정상 상태로 변경되었을 때 자동으로 교체하지 않도록 합니다. ( 에러 로그 확인 후 수동으로 교체 필요 )
  # 필요에 따라 "AZRebalance", "AlarmNotification", "ScheduledActions" 등 다른 프로세스도 일시 중지할 수 있습니다.
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#suspended_processes-1
  suspended_processes = ["ReplaceUnhealthy"] 
  
  # 🎯 인스턴스 새로 고침 (Instance Refresh) 설정 추가 또는 확인
  instance_refresh {
    strategy = "Rolling" # 점진적 교체 방식 (다른 옵션: "Replace")
    preferences {
      # 새로 고침 중 유지해야 할 최소 정상 인스턴스 비율.
      # 예: 100%로 설정하면, 새 인스턴스가 정상화된 후 이전 인스턴스를 종료 (더 안전하지만 느림)
      # 예: 90%로 설정하면, 전체 용량의 10%까지만 동시에 교체 진행 가능
      min_healthy_percentage = var.asg_min_healthy_percentage

      # 새 인스턴스가 시작된 후 애플리케이션이 완전히 준비되고 헬스 체크를 통과할 때까지 대기하는 시간(초).
      # 이 시간 동안에는 min_healthy_percentage 계산에 포함되지 않거나, 헬스 체크를 유예합니다.
      instance_warmup = var.asg_instance_warmup

      # 새로 고침을 특정 비율에서 일시 중지하고 대기할 수 있는 체크포인트 설정 (선택 사항)
      # checkpoint_percentages = [33, 66, 100]
      # checkpoint_delay       = "PT5M" # 각 체크포인트에서 5분 대기 (ISO 8601 duration format)

      # 기타 고급 설정:
      # scale_in_protected_instances = "Refresh" # 축소 방지된 인스턴스도 새로고침에 포함할지 여부
      # standby_instances            = "Terminate" # 대기 상태 인스턴스 처리 방법
    }
    # 어떤 변경이 있을 때 새로 고침을 트리거할지 지정할 수 있습니다.
    # 시작 템플릿 버전 변경은 ASG가 launch_template.version = "$Latest" 또는 .latest_version 을 사용할 때
    # 자동으로 감지하고 업데이트를 시도하는 경향이 있지만, 명시적인 트리거를 설정할 수도 있습니다.
    # 예를 들어, ASG의 특정 태그 값이 변경될 때 새로고침을 강제할 수 있습니다.
    # triggers = ["tag"] # 예시: 태그 변경 시 새로고침 (이 경우 관련 태그도 관리해야 함)
    # 현재는 launch_template의 version 변경을 주된 트리거로 간주합니다.
    # triggers = ["launch_template"] 기본값이므로 굳이 명시적으로 설정할 필요는 없습니다.
  }

  # ASG가 생성하는 인스턴스에 자동으로 태그 전파
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
}
