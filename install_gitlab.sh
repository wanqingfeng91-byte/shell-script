#!/usr/bin/env bash
set -euo pipefail

echo "🚀 GitLab 安装脚本（Ubuntu Omnibus）"

# ============================
# 0. root / sudo 兼容
# ============================
if [[ $EUID -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

# ============================
# 1. 可配置项（环境变量可覆盖）
# ============================
GITLAB_EDITION="${GITLAB_EDITION:-ce}"   # ce / ee
EXTERNAL_URL="${EXTERNAL_URL:-http://$(hostname -I | awk '{print $1}')}"
CLEAN_GITLAB="${CLEAN_GITLAB:-false}"

echo "📦 版本: gitlab-${GITLAB_EDITION}"
echo "🌐 访问地址: ${EXTERNAL_URL}"
echo "🧹 清理旧版本: ${CLEAN_GITLAB}"

# ============================
# 2. 可选清理
# ============================
if dpkg -l | grep -q gitlab; then
  echo "⚠️ 检测到已安装 GitLab"
  if [[ "${CLEAN_GITLAB}" == "true" ]]; then
    echo "🧹 清理旧 GitLab..."
    $SUDO gitlab-ctl stop || true
    $SUDO apt purge -y gitlab-* || true
    $SUDO rm -rf /etc/gitlab /var/opt/gitlab /var/log/gitlab
    echo "✅ 清理完成"
  else
    echo "❌ 已安装 GitLab，未开启 CLEAN_GITLAB"
    exit 1
  fi
fi

# ============================
# 3. 安装依赖
# ============================
echo "🔄 更新系统..."
$SUDO apt update -y
$SUDO apt install -y curl ca-certificates apt-transport-https

# ============================
# 4. 添加 GitLab 官方仓库
# ============================
echo "📦 添加 GitLab 仓库..."
if [[ "${GITLAB_EDITION}" == "ce" ]]; then
  curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | $SUDO bash
elif [[ "${GITLAB_EDITION}" == "ee" ]]; then
  curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | $SUDO bash
else
  echo "❌ GITLAB_EDITION 只能是 ce 或 ee"
  exit 1
fi

# ============================
# 5. 安装 GitLab
# ============================
echo "🚀 安装 GitLab..."
$SUDO apt update -y
$SUDO apt install -y gitlab-${GITLAB_EDITION}

# ============================
# 6. 配置 External URL
# ============================
echo "⚙️ 配置 External URL..."
$SUDO EXTERNAL_URL="${EXTERNAL_URL}" gitlab-ctl reconfigure

# ============================
# 7. 启动检测
# ============================
echo "⏳ 等待 GitLab 启动..."

for i in {1..30}; do
  if curl -s --head "${EXTERNAL_URL}" | grep -q "200 OK"; then
    echo "✅ GitLab Web 已启动"
    break
  fi
  echo "⌛ 第 $i 次检测，未就绪..."
  sleep 10
done

echo ""
echo "🔍 GitLab 服务状态："
$SUDO gitlab-ctl status || true

echo ""
echo "🎉 安装完成"
echo "👉 访问地址: ${EXTERNAL_URL}"

# ============================
# 8. 输出 root 初始密码
# ============================
if [[ -f /etc/gitlab/initial_root_password ]]; then
  echo ""
  echo "🔑 Root 初始密码："
  $SUDO cat /etc/gitlab/initial_root_password | grep Password
else
  echo ""
  echo "⚠️ 未找到 initial_root_password 文件"
fi

