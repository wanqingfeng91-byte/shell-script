#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Jenkins 安装脚本（环境检查 / 可选清理 / 插件初始化）"

# ============================
# 0. sudo / root 兼容
# ============================
if [[ $EUID -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

# ============================
# ⭐ 强制 APT 使用 IPv4（核心修改）
# ============================
APT_OPTS=(
  "-o" "Acquire::ForceIPv4=true"
  "-o" "Acquire::http::Timeout=20"
  "-o" "Acquire::https::Timeout=20"
  "-o" "Acquire::Retries=2"
)

# ============================
# 1. 开关配置（环境变量可覆盖）
# ============================
CLEAN_JENKINS="${CLEAN_JENKINS:-true}"
INIT_PLUGINS="${INIT_PLUGINS:-true}"

PLUGIN_PKG="${PLUGIN_PKG:-/opt/jenkins-plugins/jenkins-plugins.tar.gz}"

JENKINS_HOME="/var/lib/jenkins"
PLUGIN_DIR="${JENKINS_HOME}/plugins"

echo "🧹 Jenkins 清理模式：${CLEAN_JENKINS}"
echo "🧩 插件初始化模式：${INIT_PLUGINS}"
echo "📦 插件包路径：${PLUGIN_PKG}"

# ============================
# 2. Java 检查
# ============================
INSTALL_JAVA=false
if command -v java >/dev/null 2>&1; then
  echo "☕ 已检测到 Java："
  java -version
else
  echo "ℹ️ 未检测到 Java，将安装 Java 21"
  INSTALL_JAVA=true
fi

# ============================
# 3. Jenkins 检查 & 可选清理
# ============================
if dpkg -l | grep -q '^ii\s\+jenkins'; then
  echo "⚠️ Jenkins 已安装"

  if [[ "${CLEAN_JENKINS}" == "true" ]]; then
    echo "🧹 清理 Jenkins..."
    $SUDO systemctl stop jenkins || true
    $SUDO apt purge -y jenkins
    $SUDO rm -rf /var/lib/jenkins
    $SUDO rm -f /etc/apt/sources.list.d/jenkins.list
    echo "✅ Jenkins 已清理完成"
  else
    echo "❌ Jenkins 已存在，未开启 CLEAN_JENKINS"
    exit 1
  fi
else
  echo "ℹ️ 未检测到 Jenkins，将进行安装"
fi

# ============================
# 4. 更新系统（IPv4）
# ============================
echo "🔄 更新 apt 索引（IPv4）"
$SUDO apt "${APT_OPTS[@]}" update -y

# ============================
# 5. 安装 Java（IPv4）
# ============================
if [[ "${INSTALL_JAVA}" == "true" ]]; then
  echo "☕ 安装 Java 21"
  $SUDO apt "${APT_OPTS[@]}" install -y fontconfig openjdk-21-jre
fi

# ============================
# 6. Jenkins GPG Key（IPv4）
# ============================
KEYRING_DIR="/etc/apt/keyrings"
KEY_FILE="${KEYRING_DIR}/jenkins-keyring.asc"
$SUDO mkdir -p "${KEYRING_DIR}"

if [[ ! -f "${KEY_FILE}" ]]; then
  echo "🔑 下载 Jenkins GPG Key（IPv4）"
  $SUDO wget -4 -q -O "${KEY_FILE}" \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
fi

# ============================
# 7. Jenkins APT 源
# ============================
JENKINS_LIST="/etc/apt/sources.list.d/jenkins.list"

if [[ ! -f "${JENKINS_LIST}" ]]; then
  echo "📦 添加 Jenkins APT 源"
  echo "deb [signed-by=${KEY_FILE}] https://pkg.jenkins.io/debian-stable binary/" \
    | $SUDO tee "${JENKINS_LIST}" >/dev/null
fi

# ============================
# 8. 安装 Jenkins（APT → deb 兜底）
# ============================
echo "🚀 安装 Jenkins（IPv4｜APT 优先）"
$SUDO apt "${APT_OPTS[@]}" update -y

if ! $SUDO apt "${APT_OPTS[@]}" install -y jenkins; then
  echo "⚠️ APT 安装 Jenkins 失败，启用 deb 镜像兜底"

  JENKINS_VERSION="2.528.3"
  TMP_DEB="/tmp/jenkins_${JENKINS_VERSION}.deb"

  MIRRORS=(
    "https://mirrors.aliyun.com/jenkins/debian-stable/jenkins_${JENKINS_VERSION}_all.deb"
    "https://mirrors.tuna.tsinghua.edu.cn/jenkins/debian-stable/jenkins_${JENKINS_VERSION}_all.deb"
    "https://get.jenkins.io/debian-stable/jenkins_${JENKINS_VERSION}_all.deb"
  )

  for url in "${MIRRORS[@]}"; do
    echo "🌐 尝试下载（IPv4）：$url"
    if curl -4 -fL --connect-timeout 10 --max-time 120 \
      --retry 2 --retry-delay 5 \
      -o "${TMP_DEB}" "$url"; then
      echo "✅ Jenkins deb 下载成功"
      $SUDO dpkg -i "${TMP_DEB}" || $SUDO apt -f install -y
      break
    fi
  done
fi

# ⛔ 防止 Jenkins 自动初始化
$SUDO systemctl stop jenkins || true


# ============================
# 9. 插件初始化（首次启动前）
# ============================
if [[ "${INIT_PLUGINS}" == "true" ]]; then
  echo "🧩 插件初始化模式开启（首次启动前）"

  if [[ ! -f "${PLUGIN_PKG}" ]]; then
    echo "ℹ️ 未检测到插件包，跳过插件初始化"
  else
    echo "📂 准备插件目录"
    $SUDO mkdir -p "${PLUGIN_DIR}"

    echo "📦 解压插件包"
    case "${PLUGIN_PKG}" in
      *.tar.gz|*.tgz)
        $SUDO tar -xzf "${PLUGIN_PKG}" -C "${PLUGIN_DIR}"
        ;;
      *.zip)
        $SUDO unzip -oq "${PLUGIN_PKG}" -d "${PLUGIN_DIR}"
        ;;
      *)
        echo "❌ 不支持的插件包格式"
        ;;
    esac

    if [[ -d "${PLUGIN_DIR}/plugins" ]]; then
      echo "🔧 修正 plugins 嵌套目录"
      $SUDO mv "${PLUGIN_DIR}/plugins/"* "${PLUGIN_DIR}/"
      $SUDO rmdir "${PLUGIN_DIR}/plugins" || true
    fi

    echo "🧹 清理插件锁文件"
    $SUDO rm -f "${PLUGIN_DIR}"/*.lock

    echo "🔐 修正插件权限"
    $SUDO chown -R jenkins:jenkins "${JENKINS_HOME}"
  fi
fi

# ============================
# 10. 第一次启动 Jenkins
# ============================
echo "▶️ 启动 Jenkins（首次初始化）"
$SUDO systemctl enable jenkins
$SUDO systemctl start jenkins
sleep 5

if systemctl is-active --quiet jenkins; then
  echo "✅ Jenkins 启动成功（插件已加载）"
else
  echo "❌ Jenkins 启动失败"
  journalctl -u jenkins -xe
  exit 1
fi

# ============================
# 11. 输出访问信息
# ============================
IP=$(ip route get 1 | awk '{print $7; exit}')

echo ""
echo "🎉 Jenkins 安装完成"
echo "🌐 访问地址： http://${IP}:8080"
echo ""
echo "🔑 初始管理员密码："
$SUDO cat /var/lib/jenkins/secrets/initialAdminPassword

