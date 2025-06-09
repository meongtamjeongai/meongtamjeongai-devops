#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -e # 한 명령어라도 실패하면 스크립트 중단

echo "--- $(date) --- Starting EC2 User Data Script (v4 with ECR/Docker Hub detection) ---"

# Terraform templatefile을 통해 전달될 변수들
FASTAPI_IMAGE_URI="${fastapi_docker_image_placeholder}"
CONTAINER_INTERNAL_PORT="${container_internal_port_placeholder}"
HOST_EXPOSED_PORT="${host_exposed_port_placeholder}"
AWS_REGION="${aws_region_placeholder}"

# 1. Docker 설치 (기존과 동일)
echo "Installing Docker..."
sudo yum update -y -q
sudo amazon-linux-extras install docker -y -q
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
echo "Docker installed and started."

# 2. Docker 데몬이 완전히 준비될 때까지 대기 (기존과 동일)
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

# 3. 🎯 조건부 ECR 로그인 (핵심 수정 사항)
# 이미지 URI에 ".dkr.ecr." 문자열이 포함되어 있는지 확인하여 ECR 이미지 여부를 판단합니다.
if [[ "$FASTAPI_IMAGE_URI" == *".dkr.ecr."* ]]; then
  ECR_REGISTRY_FULL_URI=$(echo "$FASTAPI_IMAGE_URI" | cut -d'/' -f1)
  echo "ECR image detected. Attempting to log in to ECR: $ECR_REGISTRY_FULL_URI"
  if ! sudo aws ecr get-login-password --region "$AWS_REGION" | sudo docker login --username AWS --password-stdin "$ECR_REGISTRY_FULL_URI"; then
    echo "::error:: Failed to log in to ECR. Please check IAM role permissions (AmazonEC2ContainerRegistryReadOnly) and ECR repository URI."
    exit 1
  fi
  echo "ECR login successful."
else
  echo "Public image (e.g., Docker Hub) detected: [$FASTAPI_IMAGE_URI]. Skipping ECR login."
fi

# 4. 지정된 Docker 이미지 Pull (이제 ECR/Docker Hub 모두 처리 가능)
echo "Pulling Docker image: $FASTAPI_IMAGE_URI ..."
if ! sudo docker pull "$FASTAPI_IMAGE_URI"; then
  echo "::error:: Failed to pull Docker image: $FASTAPI_IMAGE_URI. Check image URI, tag, and repository access."
  exit 1
fi
echo "Docker image pulled successfully: $FASTAPI_IMAGE_URI"

# 5. Docker 컨테이너 실행 (기존과 동일)
echo "Running Docker container from image: $FASTAPI_IMAGE_URI on host port $HOST_EXPOSED_PORT mapping to container port $CONTAINER_INTERNAL_PORT..."
CONTAINER_NAME="fastapi_app_container"
if [ "$(sudo docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Attempting to remove existing container: $CONTAINER_NAME"
    sudo docker rm -f $CONTAINER_NAME
fi
if ! sudo docker run -d --name $CONTAINER_NAME --restart always -p "$HOST_EXPOSED_PORT":"$CONTAINER_INTERNAL_PORT" "$FASTAPI_IMAGE_URI"; then
  echo "::error:: Failed to run Docker container for image: $FASTAPI_IMAGE_URI"
  sleep 2
  EXITED_CONTAINER_ID=$(sudo docker ps -a --filter "ancestor=$FASTAPI_IMAGE_URI" --filter "status=exited" --format "{{.ID}}" | head -n 1)
  if [ -n "$EXITED_CONTAINER_ID" ]; then
    echo "Logs from recently exited container $EXITED_CONTAINER_ID:"
    sudo docker logs "$EXITED_CONTAINER_ID"
  fi
  exit 1
fi
echo "Docker container $CONTAINER_NAME started in detached mode."

# 6. 컨테이너가 실제로 실행 중인지 잠시 후 확인 (기존과 동일)
sleep 10
RUNNING_CONTAINER_ID=$(sudo docker ps -q --filter "name=$CONTAINER_NAME" --filter "status=running")
if [ -z "$RUNNING_CONTAINER_ID" ]; then
  echo "::error:: Docker container $CONTAINER_NAME is NOT running after start attempt."
  # ... (종료된 컨테이너 로그 확인 로직) ...
  exit 1
else
  echo "Docker container $CONTAINER_NAME (ID: $RUNNING_CONTAINER_ID) for image $FASTAPI_IMAGE_URI is confirmed to be running."
fi

echo "--- $(date) --- EC2 User Data Script Finished Successfully ---"