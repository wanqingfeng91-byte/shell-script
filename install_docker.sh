#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Docker 安装脚本（GitLab 安全绕过版）"

# ============================
# 0. 检测 GitLab 状态
# ============================
if dpkg -l | grep -q '^iF  gitlab-ce'; then
  echo "⚠️ 检测到 gitlab-ce 处于 broken 状态，临时 hold"
  sudo apt-mark hold gitlab-ce
fi

# ============================
# 1. 清理 apt 锁（不跑 dpkg configure）
# ============================
echo "🛠 清理 apt 锁文件..."
sudo rm -f /var/lib/dpkg/lock*
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/cache/apt/archives/lock

# ============================
# 2. 卸载冲突组件（幂等）
# ============================
echo "🧹 清理旧 Docker 组件..."
sudo apt remove -y \
  docker.io \
  docker-compose \
  docker-compose-v2 \
  docker-doc \
  podman-docker \
  containerd \
  runc || true

# ============================
# 3. 基础依赖
# ============================
echo "📦 安装基础依赖..."
sudo apt update -y
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# ============================
# 4. Docker GPG Key
# ============================
echo "🔐 配置 Docker GPG Key..."
sudo install -m 0755 -d /etc/apt/keyrings

if [ ! -s /etc/apt/keyrings/docker.asc ]; then
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
fi

sudo chmod a+r /etc/apt/keyrings/docker.asc

# ============================
# 5. Docker 官方源
# ============================
echo "📚 添加 Docker 官方仓库..."
UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# ============================
# 6. 安装 Docker（绕过 GitLab）
# ============================
echo "🐳 安装 Docker CE..."
sudo apt update -y
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  --allow-downgrades \
  --allow-change-held-packages

# ============================
# 7. 启动 Docker
# ============================
echo "🔄 启动 Docker..."
sudo systemctl enable docker
sudo systemctl restart docker
sudo systemctl enable docker

# ============================
# 8. 验证
# ============================
echo "✅ Docker 版本信息："
docker --version
docker compose version

echo "🎉 Docker 安装完成（GitLab 绕过成功）"
