#!/usr/bin/env bash
set -euo pipefail

echo "🚀 开始安装 Rancher（Docker 单节点）"

START_TIME=$(date +%s)

# ============================
# 0. 基础检查
# ============================
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ 未检测到 docker，请先安装 Docker"
  exit 1
fi

MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
if [ "$MEM_TOTAL" -lt 3800 ]; then
  echo "⚠️ 警告：当前内存 ${MEM_TOTAL}MB，Rancher 推荐 ≥ 4GB"
fi

# ============================
# 1. 获取服务器 IP（优先公网）
# ============================
get_ip() {
  ip=$(curl -s --max-time 2 https://api.ipify.org || true)
  if [[ -z "$ip" ]]; then
    ip=$(ip route get 1 | awk '{print $7; exit}')
  fi
  echo "$ip"
}

SERVER_IP=$(get_ip)

if [[ -z "${SERVER_IP}" ]]; then
  echo "❌ 无法自动获取服务器 IP"
  exit 1
fi

# ============================
# 2. 变量
# ============================
RANCHER_VERSION="v2.12.0"
RANCHER_NAME="rancher"
RANCHER_DATA_DIR="/var/lib/rancher"
HTTP_PORT=80
HTTPS_PORT=443

# ============================
# 3. 端口检查
# ============================
check_port() {
  local port=$1
  if ss -lnt | awk '{print $4}' | grep -q ":${port}$"; then
    echo "❌ 端口 ${port} 已被占用"
    exit 1
  fi
}

check_port ${HTTP_PORT}
check_port ${HTTPS_PORT}

# ============================
# 4. 清理旧 Rancher
# ============================
echo "🧹 清理旧 Rancher 容器..."
docker stop ${RANCHER_NAME} >/dev/null 2>&1 || true
docker rm ${RANCHER_NAME} >/dev/null 2>&1 || true

# ============================
# 5. 数据目录
# ============================
echo "📁 准备数据目录 ${RANCHER_DATA_DIR}..."
mkdir -p ${RANCHER_DATA_DIR}
chmod 700 ${RANCHER_DATA_DIR}

# ============================
# 6. 拉取镜像
# ============================
echo "📦 拉取 Rancher 镜像 ${RANCHER_VERSION}..."
docker pull rancher/rancher:${RANCHER_VERSION}

# ============================
# 7. 启动 Rancher
# ============================
echo "🐄 启动 Rancher..."
docker run -d \
  --name ${RANCHER_NAME} \
  --restart=unless-stopped \
  --privileged \
  -p ${HTTP_PORT}:80 \
  -p ${HTTPS_PORT}:443 \
  -v ${RANCHER_DATA_DIR}:/var/lib/rancher \
  rancher/rancher:${RANCHER_VERSION}

# ============================
# 8. 等待 API Ready（ASCII 进度条）
# ============================
echo "⏳ 等待 Rancher API 就绪..."

TOTAL_STEPS=30
BAR_WIDTH=30

for ((i=1;i<=TOTAL_STEPS;i++)); do
  if curl -sk https://${SERVER_IP}/ping | grep -q pong; then
    END_TIME=$(date +%s)
    COST=$((END_TIME - START_TIME))
    echo -e "\r[##############################] 100% (${COST}s)"
    echo "✅ Rancher 已就绪（用时 ${COST}s）"
    break
  fi

  PROGRESS=$((i * BAR_WIDTH / TOTAL_STEPS))
  REMAIN=$((BAR_WIDTH - PROGRESS))

  BAR=$(printf "%${PROGRESS}s" | tr ' ' '#')
  SPACE=$(printf "%${REMAIN}s" | tr ' ' '-')
  PERCENT=$((i * 100 / TOTAL_STEPS))
  ELAPSED=$(( $(date +%s) - START_TIME ))

  printf "\r[%-30s] %d%% (%ds)" "${BAR}${SPACE}" "${PERCENT}" "${ELAPSED}"
  sleep 3
done

echo ""

# ============================
# 9. 输出结果
# ============================
echo "🎉 Rancher 安装完成"
echo "🌐 访问地址："
echo "   👉 https://${SERVER_IP}"
echo ""
echo "📄 实时日志："
echo "   docker logs -f ${RANCHER_NAME}"