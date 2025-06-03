#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -e # 한 명령어라도 실패하면 스크립트 중단

echo "--- $(date) --- Starting EC2 User Data Script (v2 with ECR login & checks) ---"

# Terraform templatefile을 통해 전달될 변수들
FASTAPI_IMAGE_URI="${fastapi_docker_image_placeholder}"
CONTAINER_INTERNAL_PORT="${container_internal_port_placeholder}"
HOST_EXPOSED_PORT="${host_exposed_port_placeholder}"
AWS_REGION="${aws_region_placeholder}"
ECR_REGISTRY_FULL_URI=$(echo "$FASTAPI_IMAGE_URI" | cut -d'/' -f1) # 예: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com

# 1. Docker 설치
echo "Installing Docker..."
sudo yum update -y -q # -q 옵션으로 출력 줄임
sudo amazon-linux-extras install docker -y -q
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user # ec2-user가 sudo 없이 docker 명령어 사용 가능하도록 (재로그인 필요)
echo "Docker installed and started."

# 2. Docker 데몬이 완전히 준비될 때까지 대기 (최대 5번, 5초 간격으로 재시도)
echo "Waiting for Docker daemon to be ready..."
RETRY_COUNT=0
MAX_RETRIES=5
SLEEP_DURATION=5
until sudo docker info > /dev/null 2>&1; do
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "::error:: Docker daemon did not start after $MAX_RETRIES retries."
    exit 1
  fi
  echo "Docker daemon not yet ready, retrying in $SLEEP_DURATION seconds... (Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
  sleep $SLEEP_DURATION
  RETRY_COUNT=$((RETRY_COUNT + 1))
done
echo "Docker daemon is ready."

# 3. AWS CLI를 사용하여 ECR에 명시적으로 로그인
echo "Attempting to log in to ECR: $ECR_REGISTRY_FULL_URI"
if ! sudo aws ecr get-login-password --region "$AWS_REGION" | sudo docker login --username AWS --password-stdin "$ECR_REGISTRY_FULL_URI"; then
  echo "::error:: Failed to log in to ECR. Please check IAM role permissions (AmazonEC2ContainerRegistryReadOnly) and ECR repository URI."
  # ECR 로그인 실패 시 상세 디버그 정보 얻기 (선택적)
  # sudo aws ecr get-login-password --region "$AWS_REGION" --debug
  exit 1
fi
echo "ECR login successful."

# 4. 지정된 Docker 이미지 Pull
echo "Pulling Docker image: $FASTAPI_IMAGE_URI ..."
if ! sudo docker pull "$FASTAPI_IMAGE_URI"; then
  echo "::error:: Failed to pull Docker image: $FASTAPI_IMAGE_URI. Check image URI, tag, and ECR repository."
  exit 1
fi
echo "Docker image pulled successfully: $FASTAPI_IMAGE_URI"

# 5. Docker 컨테이너 실행
echo "Running Docker container from image: $FASTAPI_IMAGE_URI on host port $HOST_EXPOSED_PORT mapping to container port $CONTAINER_INTERNAL_PORT..."
# 기존 컨테이너가 있다면 충돌 방지를 위해 이름으로 삭제 후 실행 (선택적)
CONTAINER_NAME="fastapi_app_container"
if [ "$(sudo docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Attempting to remove existing container: $CONTAINER_NAME"
    sudo docker rm -f $CONTAINER_NAME
fi
if ! sudo docker run -d --name $CONTAINER_NAME --restart always -p "$HOST_EXPOSED_PORT":"$CONTAINER_INTERNAL_PORT" "$FASTAPI_IMAGE_URI"; then
  echo "::error:: Failed to run Docker container for image: $FASTAPI_IMAGE_URI"
  # 최근 종료된 컨테이너 로그 확인 시도 (오류 원인 파악에 도움)
  sleep 2 # docker run -d 직후 바로 로그가 안 나올 수 있어 잠시 대기
  EXITED_CONTAINER_ID=$(sudo docker ps -a --filter "ancestor=$FASTAPI_IMAGE_URI" --filter "status=exited" --format "{{.ID}}" | head -n 1)
  if [ -n "$EXITED_CONTAINER_ID" ]; then
    echo "Logs from recently exited container $EXITED_CONTAINER_ID:"
    sudo docker logs "$EXITED_CONTAINER_ID"
  fi
  exit 1
fi
echo "Docker container $CONTAINER_NAME started in detached mode."

# 6. 컨테이너가 실제로 실행 중인지 잠시 후 확인
sleep 10 # 컨테이너가 시작되거나 바로 종료될 수 있는 시간 부여
RUNNING_CONTAINER_ID=$(sudo docker ps -q --filter "name=$CONTAINER_NAME" --filter "status=running")
if [ -z "$RUNNING_CONTAINER_ID" ]; then
  echo "::error:: Docker container $CONTAINER_NAME is NOT running after start attempt."
  echo "Checking for any containers (even exited) with that name:"
  sudo docker ps -a --filter "name=$CONTAINER_NAME" --format "ContainerID: {{.ID}}\tStatus: {{.Status}}\tNames: {{.Names}}"
  LATEST_EXITED_ID_BY_NAME=$(sudo docker ps -a --filter "name=$CONTAINER_NAME" --filter "status=exited" --format "{{.ID}}" | head -n 1)
  if [ -n "$LATEST_EXITED_ID_BY_NAME" ]; then
    echo "Logs from recently exited container $LATEST_EXITED_ID_BY_NAME ($CONTAINER_NAME):"
    sudo docker logs "$LATEST_EXITED_ID_BY_NAME"
  fi
  exit 1
else
  echo "Docker container $CONTAINER_NAME (ID: $RUNNING_CONTAINER_ID) for image $FASTAPI_IMAGE_URI is confirmed to be running."
fi

echo "--- $(date) --- EC2 User Data Script Finished Successfully ---"