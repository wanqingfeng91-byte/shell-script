#!/usr/bin/env bash
set -euo pipefail

NERDCTL_VERSION="2.1.2"
BUILDKIT_VERSION="0.13.2"

INSTALL_DIR="/usr/local/containerd/bin"
BIN_DIR="/usr/local/bin"

echo "========================================"
echo "🚀 Installing nerdctl + buildctl"
echo "========================================"

mkdir -p ${INSTALL_DIR}

cd /tmp

#######################################
# 1. Install nerdctl
#######################################
if ! command -v nerdctl &> /dev/null; then
    echo "📦 Downloading nerdctl v${NERDCTL_VERSION}..."
    wget -q https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz
    
    echo "📂 Extracting nerdctl..."
    tar xf nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz -C ${INSTALL_DIR}
    
    ln -sf ${INSTALL_DIR}/nerdctl ${BIN_DIR}/nerdctl
else
    echo "✅ nerdctl already installed"
fi

#######################################
# 2. Install buildctl (BuildKit)
#######################################
if ! command -v buildctl &> /dev/null; then
    echo "📦 Downloading buildkit v${BUILDKIT_VERSION}..."
    wget -q https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-amd64.tar.gz
    
    echo "📂 Extracting buildkit..."
    tar xf buildkit-v${BUILDKIT_VERSION}.linux-amd64.tar.gz
    
    cp bin/buildctl ${INSTALL_DIR}/
    cp bin/buildkitd ${INSTALL_DIR}/
    
    chmod +x ${INSTALL_DIR}/buildctl
    chmod +x ${INSTALL_DIR}/buildkitd
    
    ln -sf ${INSTALL_DIR}/buildctl ${BIN_DIR}/buildctl
    ln -sf ${INSTALL_DIR}/buildkitd ${BIN_DIR}/buildkitd
    
    rm -rf bin
else
    echo "✅ buildctl already installed"
fi

#######################################
# 3. Verify
#######################################
echo ""
echo "🔎 Verifying installation..."
echo "--------------------------------"
nerdctl version || true
echo ""
buildctl --version || true

echo ""
echo "🎉 Installation complete!"
echo "========================================"

