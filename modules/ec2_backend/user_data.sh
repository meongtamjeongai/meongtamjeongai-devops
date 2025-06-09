#!/bin/bash
# modules/ec2_backend/user_data.sh (Corrected Final Version)

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -e

echo "--- $(date) --- Starting EC2 User Data Script ---"

# Terraform templatefile을 통해 전달될 변수들
FASTAPI_IMAGE_URI="${fastapi_docker_image_placeholder}"
HOST_EXPOSED_PORT="${host_exposed_port_placeholder}"
CONTAINER_INTERNAL_PORT="${container_internal_port_placeholder}"
AWS_REGION="${aws_region_placeholder}"
DATABASE_URL="${database_url_placeholder}"
SECRET_KEY="${secret_key_placeholder}"
FIREBASE_B64_JSON="${firebase_b64_json_placeholder}"

# ... (Docker 설치 및 ECR 로그인 로직은 동일) ...
echo "Installing Docker..."
sudo yum update -y -q
sudo amazon-linux-extras install docker -y -q
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

echo "Waiting for Docker daemon..."
# ... (Docker 데몬 대기 로직) ...

if [[ "$FASTAPI_IMAGE_URI" == *".dkr.ecr."* ]]; then
  echo "ECR image detected. Logging in to ECR..."
  # ... (ECR 로그인 로직) ...
fi

echo "Pulling Docker image: $FASTAPI_IMAGE_URI ..."
sudo docker pull "$FASTAPI_IMAGE_URI"

# 5. Docker 컨테이너 실행 (환경 변수 주입 및 예외 처리 포함)
echo "Running Docker container with environment variables..."
CONTAINER_NAME="fastapi_app_container"
if [ "$(sudo docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Attempting to remove existing container: $CONTAINER_NAME"
    sudo docker rm -f $CONTAINER_NAME
fi

# 💡 docker run 명령어
if ! sudo docker run -d --name $CONTAINER_NAME --restart always \
  -p "$HOST_EXPOSED_PORT":"$CONTAINER_INTERNAL_PORT" \
  -e APP_ENV="prod" \
  -e DATABASE_URL="$DATABASE_URL" \
  -e SECRET_KEY="$SECRET_KEY" \
  -e FIREBASE_SERVICE_ACCOUNT_KEY_PATH="/tmp/firebase_service_account.json" \
  -e FIREBASE_SERVICE_ACCOUNT_KEY_JSON_BASE64="$FIREBASE_B64_JSON" \
  "$FASTAPI_IMAGE_URI"; then
  
  # docker run 명령 자체가 실패한 경우
  echo "::error:: 'docker run' command failed to start the container initially."
  exit 1
fi

# 컨테이너가 시작은 되었지만, 바로 종료되었는지 확인하는 로직
echo "Container start command issued. Verifying status in 10 seconds..."
sleep 10
RUNNING_CONTAINER_ID=$(sudo docker ps -q --filter "name=$CONTAINER_NAME" --filter "status=running")

if [ -z "$RUNNING_CONTAINER_ID" ]; then
  echo "::error:: Container is not in 'running' state after start attempt."
  EXITED_CONTAINER_ID=$(sudo docker ps -a --filter "name=$CONTAINER_NAME" --filter "status=exited" --format "{{.ID}}" | head -n 1)
  
  if [ -n "$EXITED_CONTAINER_ID" ]; then
    echo "Logs from recently exited container $EXITED_CONTAINER_ID:"
    sudo docker logs "$EXITED_CONTAINER_ID"
  else
    echo "Could not find a recently exited container with the name $CONTAINER_NAME."
  fi
  exit 1
fi

echo "✅ Docker container $CONTAINER_NAME (ID: $RUNNING_CONTAINER_ID) is confirmed to be running."
echo "--- $(date) --- EC2 User Data Script Finished Successfully ---"