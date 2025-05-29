terraform {
  required_providers {
    # null_resource를 사용하기 위한 공급자 설정
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  # VCS 기반 워크플로우에서는 Terraform Cloud가 backend 설정을 자동으로 주입합니다.
  # 따라서 아래 backend "remote" 블록은 보통 main.tf에 포함하지 않습니다.
  # 만약 로컬에서 'terraform init'을 실행하여 backend를 수동으로 구성하려는 특별한 경우가 아니라면,
  # 이 블록은 생략하거나 주석 처리하는 것이 일반적입니다.
  #
  # cloud {
  #   organization = "<YOUR_ORGANIZATION_NAME>" # 👈 여기에 실제 조직 이름을 입력하세요.
  #
  #   workspaces {
  #     name = "<YOUR_WORKSPACE_NAME>" # 👈 여기에 실제 작업 공간 이름을 입력하세요.
  #   }
  # }
}

# 아무 작업도 하지 않는 리소스 정의
# Terraform Cloud에서 계획 및 적용이 성공하는지 테스트하는 용도
resource "null_resource" "test_vcs" {
  triggers = {
    # 이 값을 변경하고 GitHub에 푸시하면 새로운 실행이 트리거됩니다.
    run_on_change = "v1.0.0" # 예시: 버전 변경 시 트리거
  }
}

# 간단한 출력 값 정의
output "vcs_test_message" {
  value = "🚀 GitHub 연동 Terraform Cloud VCS 테스트 성공!"
}