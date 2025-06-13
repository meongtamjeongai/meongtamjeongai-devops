#!/bin/bash
# modules/ec2_backend/user_data.sh (최종 수정 버전 - $$ 이스케이프 적용)

# 로그를 Cloud-init 로그와 시스템 로그 모두에 기록
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -e

echo "--- $(date) --- EC2 User Data Script 시작 ---"

# --- 1. 변수 설정 ---
# Terraform templatefile을 통해 전달될 변수들 (이 부분은 Terraform이 치환)
ECR_REPOSITORY_URL="${ecr_repository_url_placeholder}"
FALLBACK_IMAGE="${fallback_image_placeholder}"
HOST_EXPOSED_PORT="${host_exposed_port_placeholder}"
CONTAINER_INTERNAL_PORT="${container_internal_port_placeholder}"
AWS_REGION="${aws_region_placeholder}"
DATABASE_URL="${database_url_placeholder}"
SECRET_KEY="${secret_key_placeholder}"
FIREBASE_B64_JSON="${firebase_b64_json_placeholder}"
GEMINI_API_KEY="${gemini_api_key_placeholder}"
S3_BUCKET_NAME="${s3_bucket_name_placeholder}"

# 최종적으로 사용할 이미지를 저장할 셸 변수
FINAL_IMAGE_TO_PULL=""

# --- 2. 필수 패키지 설치 (Docker, AWS CLI) ---
echo "필수 패키지 설치 중 (Docker, AWS CLI)..."
sudo yum update -y -q
sudo amazon-linux-extras install docker -y -q
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# --- 3. 🚀 ECR 로그인 및 사용할 최종 Docker 이미지 결정 (핵심 로직) ---
echo "--- 사용할 최종 Docker 이미지 결정 시작 ---"
echo "대상 ECR 저장소 URL: $$ECR_REPOSITORY_URL"
echo "ECR 비어있을 시 Fallback 이미지: $$FALLBACK_IMAGE"

# 3-1. ECR 로그인 (항상 시도)
echo "Amazon ECR에 로그인 시도 중..."
# ECR URL에서 AWS 계정 ID와 리전 정보 추출
AWS_ACCOUNT_ID=$$(echo "$$ECR_REPOSITORY_URL" | cut -d'.' -f1)
ECR_REGISTRY_URL="$$AWS_ACCOUNT_ID.dkr.ecr.$$AWS_REGION.amazonaws.com"

if ! sudo aws ecr get-login-password --region "$$AWS_REGION" | sudo docker login --username AWS --password-stdin "$$ECR_REGISTRY_URL"; then
    echo "::error:: Amazon ECR 로그인에 실패했습니다. 스크립트를 중단합니다."
    exit 1
fi
echo "✅ Amazon ECR에 성공적으로 로그인했습니다."

# 3-2. ECR 저장소에 이미지가 있는지 확인
ECR_REPOSITORY_NAME=$$(echo "$$ECR_REPOSITORY_URL" | cut -d'/' -f2)
echo "ECR 저장소($$ECR_REPOSITORY_NAME)의 이미지 존재 여부 확인 중..."

if sudo aws ecr describe-images --repository-name "$$ECR_REPOSITORY_NAME" --region "$$AWS_REGION" --output text --query 'imageDetails[0].imageTags' | grep -q 'latest'; then
    echo "✅ ECR 저장소에 'latest' 태그 이미지가 존재합니다. ECR 이미지를 사용합니다."
    FINAL_IMAGE_TO_PULL="$$ECR_REPOSITORY_URL:latest"
else
    echo "⚠️ ECR 저장소에 'latest' 태그 이미지가 없습니다. Fallback 이미지를 사용합니다: $$FALLBACK_IMAGE"
    FINAL_IMAGE_TO_PULL="$$FALLBACK_IMAGE"
fi

echo "--- 최종적으로 사용할 이미지: $$FINAL_IMAGE_TO_PULL ---"

# --- 4. Docker 이미지 다운로드 ---
echo "Docker 이미지 다운로드 중: $$FINAL_IMAGE_TO_PULL ..."
if ! sudo docker pull "$$FINAL_IMAGE_TO_PULL"; then
  echo "::error:: Docker 이미지($$FINAL_IMAGE_TO_PULL) 다운로드에 실패했습니다."
  exit 1
fi
echo "✅ Docker 이미지를 성공적으로 다운로드했습니다."

# --- 5. Docker 컨테이너 실행 ---
echo "환경 변수와 함께 Docker 컨테이너 실행 중..."
CONTAINER_NAME="fastapi_app_container"

# 기존에 동일한 이름의 컨테이너가 있으면 강제 제거
if [ "$$(sudo docker ps -aq -f name=$$CONTAINER_NAME)" ]; then
    echo "기존 컨테이너($$CONTAINER_NAME)를 제거합니다."
    sudo docker rm -f $$CONTAINER_NAME
fi

# Docker 컨테이너 실행 (결정된 최종 이미지 사용)
if ! sudo docker run -d --name $$CONTAINER_NAME --restart always \
  -p "$$HOST_EXPOSED_PORT:$$CONTAINER_INTERNAL_PORT" \
  -e APP_ENV="prod" \
  -e DATABASE_URL="$$DATABASE_URL" \
  -e SECRET_KEY="$$SECRET_KEY" \
  -e FIREBASE_SERVICE_ACCOUNT_KEY_PATH="/tmp/firebase_service_account.json" \
  -e FIREBASE_SERVICE_ACCOUNT_KEY_JSON_BASE64="$$FIREBASE_B64_JSON" \
  -e GEMINI_API_KEY="$$GEMINI_API_KEY" \
  -e S3_BUCKET_NAME="$$S3_BUCKET_NAME" \
  "$$FINAL_IMAGE_TO_PULL"; then
  
  echo "::error:: 'docker run' 명령으로 컨테이너를 시작하지 못했습니다."
  exit 1
fi

# 컨테이너가 정상 실행 중인지 확인
echo "컨테이너 시작 명령을 보냈습니다. 10초 후 상태를 확인합니다..."
sleep 10
RUNNING_CONTAINER_ID=$$(sudo docker ps -q --filter "name=$$CONTAINER_NAME" --filter "status=running")

if [ -z "$$RUNNING_CONTAINER_ID" ]; then
  echo "::error:: 컨테이너가 'running' 상태가 아닙니다."
  EXITED_CONTAINER_ID=$$(sudo docker ps -a --filter "name=$$CONTAINER_NAME" --format "{{.ID}}" | head -n 1)
  if [ -n "$$EXITED_CONTAINER_ID" ]; then
    echo "최근에 종료된 컨테이너($$EXITED_CONTAINER_ID)의 로그:"
    sudo docker logs "$$EXITED_CONTAINER_ID"
  fi
  exit 1
fi

echo "✅ Docker 컨테이너 $$CONTAINER_NAME (ID: $$RUNNING_CONTAINER_ID)가 정상 실행 중임을 확인했습니다."
echo "--- $(date) --- EC2 User Data Script 성공적으로 완료 ---"