#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- $(date) --- Starting EC2 User Data Script ---"

# Terraform으로부터 전달받을 변수들 (templatefile 함수를 통해 값이 주입됨)
FASTAPI_IMAGE="${fastapi_docker_image_placeholder}"
CONTAINER_INTERNAL_PORT="${container_internal_port_placeholder}"
HOST_EXPOSED_PORT="${host_exposed_port_placeholder}" # 👈 새로 사용할 변수 이름 (플레이스홀더)

# Install Docker
echo "Installing Docker..."
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
echo "Docker installed and started."

echo "Pulling Docker image: $FASTAPI_IMAGE..."
sudo docker pull $FASTAPI_IMAGE

echo "Running Docker container from image: $FASTAPI_IMAGE on host port $HOST_EXPOSED_PORT mapping to container port $CONTAINER_INTERNAL_PORT..."
sudo docker run -d --restart always -p $HOST_EXPOSED_PORT:$CONTAINER_INTERNAL_PORT $FASTAPI_IMAGE

echo "Docker container should be running."
echo "--- $(date) --- EC2 User Data Script Finished ---"