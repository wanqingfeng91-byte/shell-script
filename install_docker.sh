#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "🚀 Docker CE + Docker Compose 安装脚本"
echo "=========================================="

# ============================
# 0. 清理旧 Docker 源（关键）
# ============================
echo "🧹 清理旧 Docker 仓库配置..."
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/sources.list.d/docker.sources
sudo rm -f /etc/apt/keyrings/docker.gpg
sudo rm -f /etc/apt/keyrings/docker.asc

# ============================
# 1. 卸载旧版本（幂等）
# ============================
echo "🧹 清理旧 Docker 组件..."
sudo apt remove -y \
  docker.io \
  docker-doc \
  docker-compose \
  podman-docker \
  containerd \
  runc || true

# ============================
# 2. 安装基础依赖
# ============================
echo "📦 安装基础依赖..."
sudo apt update -y
sudo apt install -y ca-certificates curl gnupg

# ============================
# 3. 添加 Docker 官方 GPG key
# ============================
echo "🔐 添加 Docker GPG Key..."
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| sudo gpg --dearmor \
| sudo tee /etc/apt/keyrings/docker.gpg > /dev/null

sudo chmod a+r /etc/apt/keyrings/docker.gpg

# ============================
# 4. 添加 Docker 官方仓库
# ============================
echo "📚 添加 Docker 官方仓库..."
ARCH=$(dpkg --print-architecture)
UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

echo \
"deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
${UBUNTU_CODENAME} stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# ============================
# 5. 安装 Docker CE
# ============================
echo "🐳 安装 Docker CE..."
sudo apt update -y
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# ============================
# 6. 启动 Docker
# ============================
echo "🔄 启动 Docker..."
sudo systemctl enable docker
sudo systemctl restart docker

# ============================
# 7. 验证
# ============================
echo "=========================================="
docker --version
docker compose version
echo "=========================================="
echo "🎉 Docker 安装完成"

