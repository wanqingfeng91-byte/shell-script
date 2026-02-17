#!/bin/bash
set -e

# ======================================================
# Harbor 2.14.0 自动安装脚本
# 适配 Ubuntu 20.04 / 22.04 / 24.04
# 自动识别IP / 自动关闭HTTPS / 自动安装
# ======================================================

HARBOR_VERSION="2.14.0"
INSTALL_DIR="/opt/harbor"
HARBOR_HTTP_PORT="8080"
HARBOR_ADMIN_PASSWORD="Harbor12345"

OFFLINE_INSTALLER_URL="https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-offline-installer-v${HARBOR_VERSION}.tgz"

echo "=================================================="
echo "🚀 Harbor ${HARBOR_VERSION} 自动安装开始"
echo "=================================================="

# ===============================
# 检查 Docker
# ===============================
if ! command -v docker &>/dev/null; then
    echo "❌ Docker 未安装"
    exit 1
fi

# 识别 docker compose 命令
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ 未检测到 Docker Compose"
    exit 1
fi

echo "✅ Docker & Compose 检测通过"

# ===============================
# 自动识别本机IP
# ===============================
HARBOR_HOSTNAME=$(hostname -I | awk '{print $1}')

if [ -z "$HARBOR_HOSTNAME" ]; then
    echo "❌ 无法识别本机IP"
    exit 1
fi

echo "🌐 自动识别 IP: $HARBOR_HOSTNAME"

# ===============================
# 创建目录
# ===============================
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ===============================
# 下载 Harbor
# ===============================
if [ ! -f harbor-offline-installer-v${HARBOR_VERSION}.tgz ]; then
    echo "⬇️  下载 Harbor 离线包..."
    wget "$OFFLINE_INSTALLER_URL"
fi

echo "📦 解压 Harbor..."
tar -xzf harbor-offline-installer-v${HARBOR_VERSION}.tgz
cd harbor

# ===============================
# 生成 harbor.yml
# ===============================
cp harbor.yml.tmpl harbor.yml

echo "⚙️  配置 Harbor..."

sed -i "s|^hostname:.*|hostname: ${HARBOR_HOSTNAME}|" harbor.yml
sed -i "s|^  port:.*|  port: ${HARBOR_HTTP_PORT}|" harbor.yml
sed -i "s|^harbor_admin_password:.*|harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}|" harbor.yml

# 彻底禁用 HTTPS
sed -i '/^https:/,/^$/s/^/#/' harbor.yml

# ===============================
# 开始安装
# ===============================
echo "🚀 开始安装 Harbor..."
./install.sh --with-trivy

echo ""
echo "=================================================="
echo "🎉 Harbor 安装完成！"
echo "访问地址: http://${HARBOR_HOSTNAME}:${HARBOR_HTTP_PORT}"
echo "账号: admin"
echo "密码: ${HARBOR_ADMIN_PASSWORD}"
echo "=================================================="

