#!/usr/bin/env bash

set -e

echo "======================================"
echo "        Kubectl Installer"
echo "======================================"

# ---------- 检查系统 ----------
if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl 未安装"
  exit 1
fi

ARCH=$(uname -m)
OS=$(uname | tr '[:upper:]' '[:lower:]')

case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "[ERROR] 不支持的架构: $ARCH"
    exit 1
    ;;
esac

echo "[OK] OS: $OS"
echo "[OK] ARCH: $ARCH"

# ---------- 选择版本 ----------
echo ""
echo "请选择 kubectl 版本："
echo "1) 最新稳定版 (stable)"
echo "2) 指定版本 (例如 v1.30.1)"
read -p "输入选择 [1-2]: " choice

if [ "$choice" == "1" ]; then
  VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
elif [ "$choice" == "2" ]; then
  read -p "请输入版本号 (例: v1.30.1): " VERSION
else
  echo "[ERROR] 无效选择"
  exit 1
fi

echo "[INFO] 安装版本: $VERSION"

# ---------- 下载 ----------
URL="https://dl.k8s.io/release/${VERSION}/bin/${OS}/${ARCH}/kubectl"

echo "[INFO] 下载 kubectl..."
curl -LO "$URL"

# ---------- 安装 ----------
chmod +x kubectl

echo "[INFO] 安装到 /usr/local/bin ..."
sudo mv kubectl /usr/local/bin/

# ---------- 验证 ----------
echo "[INFO] 验证安装..."
kubectl version --client

# ---------- bash 自动补全 ----------
echo "[INFO] 配置 bash completion..."

if ! grep -q "kubectl completion bash" ~/.bashrc; then
  echo 'source <(kubectl completion bash)' >> ~/.bashrc
fi

# alias 自动补全（高级体验）
if ! grep -q "alias k=kubectl" ~/.bashrc; then
  cat <<EOF >> ~/.bashrc

# kubectl alias
alias k=kubectl
complete -o default -F __start_kubectl k
EOF
fi

echo ""
echo "[SUCCESS] kubectl 安装完成 ✅"
echo ""
echo "请执行："
echo "    source ~/.bashrc"
echo ""
echo "或重新打开终端"