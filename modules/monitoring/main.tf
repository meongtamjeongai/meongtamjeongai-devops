# modules/monitoring/main.tf

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-main-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text",
        x      = 0,
        y      = 0,
        width  = 24,
        height = 1,
        properties = {
          markdown = "# 🚀 FastAPI Infra Dashboard (${var.project_name}-${var.environment})"
        }
      },
      # --- EC2 Backend Metrics ---
      {
        type   = "metric",
        x      = 0,
        y      = 1, # y좌표는 위젯의 세로 위치
        width  = 12,
        height = 6,
        properties = {
          title  = "EC2 Backend - CPU Utilization (%)",
          view   = "timeSeries",
          stacked = false,
          region = var.aws_region,
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.backend_asg_name]
          ],
          period = 300 # 5분 간격
        }
      },
      {
        type   = "metric",
        x      = 12, # x좌표는 위젯의 가로 위치
        y      = 1,
        width  = 12,
        height = 6,
        properties = {
          title  = "EC2 Backend - Network I/O (Bytes)",
          view   = "timeSeries",
          stacked = false,
          region = var.aws_region,
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", var.backend_asg_name, { label = "Network In" }],
            [".", "NetworkOut", ".", ".", { label = "Network Out" }]
          ],
          period = 300
        }
      },
      # --- RDS Database Metrics ---
      {
        type   = "metric",
        x      = 0,
        y      = 7,
        width  = 8,
        height = 6,
        properties = {
          title  = "RDS - CPU Utilization (%)",
          view   = "timeSeries",
          stacked = false,
          region = var.aws_region,
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_identifier]
          ],
          period = 300
        }
      },
      {
        type   = "metric",
        x      = 8,
        y      = 7,
        width  = 8,
        height = 6,
        properties = {
          title  = "RDS - Database Connections",
          view   = "timeSeries",
          stacked = false,
          region = var.aws_region,
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_identifier]
          ],
          period = 300
        }
      },
      {
        type   = "metric",
        x      = 16,
        y      = 7,
        width  = 8,
        height = 6,
        properties = {
          title  = "RDS - Freeable Memory (Bytes)",
          view   = "timeSeries",
          stacked = false,
          region = var.aws_region,
          metrics = [
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.rds_instance_identifier]
          ],
          period = 300
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# SNS Topic for Alarms
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alarms" {
  # alarm_notification_email 변수가 null이 아닐 때만 생성
  count = var.alarm_notification_email != null ? 1 : 0

  name = "${var.project_name}-${var.environment}-alarms-topic"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# SNS Topic Subscription
# -----------------------------------------------------------------------------
resource "aws_sns_topic_subscription" "email" {
  # aws_sns_topic.alarms 리소스와 동일한 조건으로 생성
  count = var.alarm_notification_email != null ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

# 경보(Alarm) 상태일 때 알림을 보낼 SNS Topic ARN 목록
# count 를 사용하는 리소스(aws_sns_topic.alarms)를 참조하므로, local 변수로 한번 정리하여 사용하면 코드가 깔끔해집니다.
locals {
  alarm_actions = length(aws_sns_topic.alarms) > 0 ? [aws_sns_topic.alarms[0].arn] : []
}

# 1. EC2 Backend CPU High Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  # 이메일 주소가 제공되었을 때만 생성
  count = var.alarm_notification_email != null ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-ec2-cpu-high"
  alarm_description   = "Alarm when EC2 CPU utilization exceeds 75% for 10 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2 # 2번 연속으로
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # 5분(300초) 간격으로 측정
  statistic           = "Average"
  threshold           = 75 # 임계치: 75%

  # 어떤 리소스를 감시할지 지정
  dimensions = {
    AutoScalingGroupName = var.backend_asg_name
  }

  # 경보 상태(ALARM)가 되었을 때 수행할 액션
  alarm_actions = local.alarm_actions
  # 정상 상태(OK)로 돌아왔을 때 수행할 액션 (선택 사항)
  ok_actions = local.alarm_actions

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Severity    = "Warning"
  }
}

# 2. RDS Free Storage Space Low Alarm
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  # 이메일 주소가 제공되었을 때만 생성
  count = var.alarm_notification_email != null ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  alarm_description   = "Alarm when RDS free storage space drops below 5 GB"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  # 임계치: 5GB (단위는 Bytes). 5 * 1024 * 1024 * 1024 = 5368709120
  threshold           = 5368709120 

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Severity    = "Critical"
  }
}
