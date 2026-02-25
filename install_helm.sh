#!/usr/bin/env bash

set -e

echo "=============================="
echo "   Helm Interactive Installer"
echo "=============================="

# ---------- 系统检测 ----------
OS=$(uname | tr '[:upper:]' '[:lower:]')

case "$OS" in
  linux|darwin) ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

ARCH=$(uname -m)

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "Unsupported ARCH: $ARCH"
    exit 1
    ;;
esac

echo "Detected: $OS/$ARCH"
echo ""

# ---------- 获取版本列表 ----------
echo "Fetching Helm versions..."

VERSIONS=($(curl -s https://api.github.com/repos/helm/helm/releases \
  | grep tag_name \
  | cut -d '"' -f4 \
  | head -n 10))

# ---------- 显示菜单 ----------
echo "Select Helm version to install:"
echo "--------------------------------"

for i in "${!VERSIONS[@]}"; do
  printf "%2d) %s\n" $((i+1)) "${VERSIONS[$i]}"
done

echo ""
read -p "Enter number (default 1): " CHOICE

CHOICE=${CHOICE:-1}

INDEX=$((CHOICE-1))
VERSION=${VERSIONS[$INDEX]}

if [ -z "$VERSION" ]; then
  echo "Invalid selection"
  exit 1
fi

echo ""
echo "You selected: $VERSION"
echo ""

# ---------- 下载 ----------
TAR_FILE="helm-${VERSION}-${OS}-${ARCH}.tar.gz"
URL="https://get.helm.sh/${TAR_FILE}"

echo "Downloading $URL ..."
curl -LO "$URL"

# ---------- 解压 ----------
tar -zxvf "$TAR_FILE"

# ---------- 安装 ----------
echo "Installing Helm..."
sudo mv "${OS}-${ARCH}/helm" /usr/local/bin/helm

# ---------- 清理 ----------
rm -rf "$TAR_FILE" "${OS}-${ARCH}"

echo ""
echo "✅ Helm installed successfully!"
echo ""

helm version