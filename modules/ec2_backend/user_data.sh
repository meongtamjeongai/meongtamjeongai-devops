#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- $(date) --- Starting EC2 User Data Script ---"

# Install Docker
echo "Installing Docker..."
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user # Add ec2-user to the docker group so you can execute Docker commands without sudo
echo "Docker installed and started."

# Pull and run FastAPI Docker image
FASTAPI_IMAGE="${fastapi_docker_image}" # Terraform에서 변수로 전달받을 값
CONTAINER_PORT="${fastapi_app_port}"    # Terraform에서 변수로 전달받을 값
HOST_PORT=80 # 호스트에서 ALB가 접근할 포트 (컨테이너 포트와 다를 수 있지만, 보통 ALB는 80으로 접근 후 컨테이너의 다른 포트로 전달 가능)

echo "Pulling Docker image: $FASTAPI_IMAGE..."
sudo docker pull $FASTAPI_IMAGE

echo "Running Docker container from image: $FASTAPI_IMAGE on host port $HOST_PORT mapping to container port $CONTAINER_PORT..."
# sudo docker run -d -p $HOST_PORT:$CONTAINER_PORT $FASTAPI_IMAGE
# 아래는 docker run 명령어 예시입니다. 실제 환경에 맞게 옵션을 조정하세요.
# --restart always: 예기치 않게 컨테이너가 종료되면 자동으로 다시 시작합니다.
# --log-driver awslogs... : 컨테이너 로그를 CloudWatch Logs로 보낼 수 있습니다 (IAM 권한 및 로그 그룹 필요).
sudo docker run -d --restart always -p $HOST_PORT:$CONTAINER_PORT $FASTAPI_IMAGE

echo "Docker container should be running."
echo "--- $(date) --- EC2 User Data Script Finished ---"