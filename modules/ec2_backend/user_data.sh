#!/bin/bash
# modules/ec2_backend/user_data.sh (Corrected Final Version)

# 로그를 Cloud-init 로그와 시스템 로그 모두에 기록
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -e

echo "--- $(date) --- Starting EC2 User Data Script ---"

# --- 1. 변수 설정 ---
# Terraform templatefile을 통해 전달될 변수들
FASTAPI_IMAGE_URI="${fastapi_docker_image_placeholder}"
HOST_EXPOSED_PORT="${host_exposed_port_placeholder}"
CONTAINER_INTERNAL_PORT="${container_internal_port_placeholder}"
AWS_REGION="${aws_region_placeholder}"
DATABASE_URL="${database_url_placeholder}"
SECRET_KEY="${secret_key_placeholder}"
FIREBASE_B64_JSON="${firebase_b64_json_placeholder}"

# --- 2. Docker 설치 및 활성화 ---
echo "Installing Docker..."
sudo yum update -y -q
sudo amazon-linux-extras install docker -y -q
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# --- 3. 💥 ECR 로그인 (가장 중요한 수정 부분) ---
# ECR 이미지를 사용하는 경우에만 로그인 시도
if [[ "$FASTAPI_IMAGE_URI" == *".dkr.ecr."* ]]; then
  echo "ECR image detected. Logging in to Amazon ECR..."
  
  # AWS CLI v2가 설치되어 있는지 확인 (Amazon Linux 2에는 기본적으로 설치됨)
  if ! command -v aws &> /dev/null; then
    echo "::error:: AWS CLI is not installed. Cannot log in to ECR."
    exit 1
  fi
  
  # ECR URL에서 AWS 계정 ID 추출
  AWS_ACCOUNT_ID=$(echo "$FASTAPI_IMAGE_URI" | cut -d'.' -f1)
  
  # AWS CLI를 사용하여 ECR 로그인 명령을 생성하고 실행
  # 이 명령은 Docker가 ECR에 인증하는 데 사용할 임시 토큰을 가져옵니다.
  # IAM 역할 권한 덕분에 Access Key 없이도 실행 가능합니다.
  if ! sudo aws ecr get-login-password --region "$AWS_REGION" | sudo docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"; then
    echo "::error:: Failed to log in to Amazon ECR."
    exit 1
  fi
  
  echo "✅ Successfully logged in to Amazon ECR."
else
  echo "Non-ECR image detected. Skipping ECR login."
fi

# --- 4. Docker 이미지 다운로드 ---
echo "Pulling Docker image: $FASTAPI_IMAGE_URI ..."
if ! sudo docker pull "$FASTAPI_IMAGE_URI"; then
  echo "::error:: Failed to pull Docker image: $FASTAPI_IMAGE_URI"
  exit 1
fi
echo "✅ Docker image pulled successfully."

# --- 5. Docker 컨테이너 실행 ---
echo "Running Docker container with environment variables..."
CONTAINER_NAME="fastapi_app_container"

# 기존에 동일한 이름의 컨테이너가 있으면 강제 제거
if [ "$(sudo docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Attempting to remove existing container: $CONTAINER_NAME"
    sudo docker rm -f $CONTAINER_NAME
fi

# Docker 컨테이너 실행
if ! sudo docker run -d --name $CONTAINER_NAME --restart always \
  -p "$HOST_EXPOSED_PORT":"$CONTAINER_INTERNAL_PORT" \
  -e APP_ENV="prod" \
  -e DATABASE_URL="$DATABASE_URL" \
  -e SECRET_KEY="$SECRET_KEY" \
  -e FIREBASE_SERVICE_ACCOUNT_KEY_PATH="/tmp/firebase_service_account.json" \
  -e FIREBASE_SERVICE_ACCOUNT_KEY_JSON_BASE64="$FIREBASE_B64_JSON" \
  "$FASTAPI_IMAGE_URI"; then
  
  echo "::error:: 'docker run' command failed to start the container."
  exit 1
fi

# 컨테이너가 정상 실행 중인지 확인
echo "Container start command issued. Verifying status in 10 seconds..."
sleep 10
RUNNING_CONTAINER_ID=$(sudo docker ps -q --filter "name=$CONTAINER_NAME" --filter "status=running")

if [ -z "$RUNNING_CONTAINER_ID" ]; then
  echo "::error:: Container is not in 'running' state after start attempt."
  EXITED_CONTAINER_ID=$(sudo docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.ID}}" | head -n 1)
  if [ -n "$EXITED_CONTAINER_ID" ]; then
    echo "Logs from recently exited container $EXITED_CONTAINER_ID:"
    sudo docker logs "$EXITED_CONTAINER_ID"
  fi
  exit 1
fi

echo "✅ Docker container $CONTAINER_NAME (ID: $RUNNING_CONTAINER_ID) is confirmed to be running."
echo "--- $(date) --- EC2 User Data Script Finished Successfully ---"