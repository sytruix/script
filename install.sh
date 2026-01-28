#!/bin/bash

# PyTunnel-Hub 服务器环境自动安装脚本
# 用法: curl -fsSL https://your-panel.com/static/install.sh | bash -s -- --server-id 1 --api-key xxx --panel-url http://panel.com

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认参数
SERVER_ID=""
API_KEY=""
PANEL_URL=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-id)
            SERVER_ID="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --panel-url)
            PANEL_URL="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            exit 1
            ;;
    esac
done

# 检查必需参数
if [ -z "$SERVER_ID" ] || [ -z "$API_KEY" ] || [ -z "$PANEL_URL" ]; then
    echo -e "${RED}错误: 缺少必需参数${NC}"
    echo "用法: $0 --server-id <id> --api-key <key> --panel-url <url>"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  PyTunnel-Hub 服务器环境安装脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "服务器ID: $SERVER_ID"
echo "面板地址: $PANEL_URL"
echo ""

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 root 用户运行此脚本${NC}"
    exit 1
fi

# 检测系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo -e "${RED}无法检测系统类型${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/6] 检测到系统: $OS $VERSION${NC}"

# 更新系统
echo -e "${YELLOW}[2/6] 更新系统包...${NC}"
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get update -qq
    apt-get install -y curl wget unzip
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
    yum install -y curl wget unzip
else
    echo -e "${RED}不支持的系统: $OS${NC}"
    exit 1
fi

# 安装 Xray 内核
echo -e "${YELLOW}[3/6] 安装 Xray 内核...${NC}"
if ! command -v xray >/dev/null 2>&1; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    echo -e "${GREEN}✓ Xray 安装完成${NC}"
else
    echo -e "${GREEN}✓ Xray 已安装，跳过${NC}"
fi

# 安装 Hysteria2 内核
echo -e "${YELLOW}[4/6] 安装 Hysteria2 内核...${NC}"
if ! command -v hysteria >/dev/null 2>&1; then
    bash <(curl -fsSL https://get.hy2.sh/)
    echo -e "${GREEN}✓ Hysteria2 安装完成${NC}"
else
    echo -e "${GREEN}✓ Hysteria2 已安装，跳过${NC}"
fi

# 创建初始配置并建立路径映射（双重保险）
echo -e "${YELLOW}[5/6] 正在配置环境与路径映射...${NC}"

# 创建两个可能的配置目录（兼容不同发行版）
mkdir -p /etc/xray /usr/local/etc/xray
mkdir -p /etc/hysteria /usr/local/etc/hysteria

# ========== Xray 配置 ==========
# 写入 Xray 初始配置到官方路径
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# 【关键】建立软链接：面板推送到 /usr/local/etc，系统从任意路径读取都一致
ln -sf /usr/local/etc/xray/config.json /etc/xray/config.json
echo -e "${GREEN}✓ Xray 配置路径映射已建立${NC}"
echo -e "  /usr/local/etc/xray/config.json ← 主配置"
echo -e "  /etc/xray/config.json → 软链接"

# ========== Hysteria2 配置 ==========
# 写入 Hysteria2 初始配置
cat > /etc/hysteria/config.yaml <<EOF
listen: :443

tls:
  cert: /etc/hysteria/cert.crt
  key: /etc/hysteria/cert.key

auth:
  type: http
  http:
    url: ${PANEL_URL}/api/traffic/auth
    insecure: false

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true
EOF

# 建立 Hysteria2 软链接（某些版本可能从 /usr/local/etc 读取）
ln -sf /etc/hysteria/config.yaml /usr/local/etc/hysteria/config.yaml
echo -e "${GREEN}✓ Hysteria2 配置路径映射已建立${NC}"
echo -e "  /etc/hysteria/config.yaml ← 主配置"
echo -e "  /usr/local/etc/hysteria/config.yaml → 软链接"

# 生成自签名证书（如果不存在）
if [ ! -f /etc/hysteria/cert.crt ]; then
    echo -e "${YELLOW}正在生成 Hysteria2 自签名证书...${NC}"
    openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/hysteria/cert.key \
        -out /etc/hysteria/cert.crt -days 3650 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com" >/dev/null 2>&1
    echo -e "${GREEN}✓ 自签名证书已生成${NC}"
fi

# 启用服务（但不立即启动，等待配置推送）
systemctl enable xray >/dev/null 2>&1 || true
systemctl enable hysteria-server >/dev/null 2>&1 || true

echo ""
echo -e "${GREEN}✓ 配置环境初始化完成${NC}"

# 保存服务器信息
cat > /etc/pytunnel-server.conf <<EOF
SERVER_ID=$SERVER_ID
API_KEY=$API_KEY
PANEL_URL=$PANEL_URL
INSTALL_DATE=$(date)
EOF

# 自动通知面板进行首次配置同步
echo ""
echo -e "${YELLOW}[6/6] 正在请求面板推送节点配置...${NC}"
SYNC_RESULT=$(curl -X POST "${PANEL_URL}/api/servers/${SERVER_ID}/sync" \
     -H "X-Node-API-Key: ${API_KEY}" \
     -H "Content-Type: application/json" \
     -s -w "\n%{http_code}" 2>/dev/null || echo "000")

HTTP_CODE=$(echo "$SYNC_RESULT" | tail -n1)
RESPONSE_BODY=$(echo "$SYNC_RESULT" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 配置同步成功${NC}"
    echo "$RESPONSE_BODY" | grep -q '"deployed_count"' && echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo -e "${YELLOW}⚠ 自动同步失败 (HTTP $HTTP_CODE)${NC}"
    echo -e "${YELLOW}  可能原因：面板上还没有创建节点实例${NC}"
    echo -e "${YELLOW}  请在面板中创建节点实例后，点击'部署'按钮${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  环境安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "服务器ID: $SERVER_ID"
echo "Xray 状态: $(systemctl is-active xray 2>/dev/null || echo '未启动')"
echo "Hysteria2 状态: $(systemctl is-active hysteria-server 2>/dev/null || echo '未启动')"
echo ""
echo "下一步："
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ 节点配置已自动推送并启动"
    echo "✓ 用户可以立即使用"
else
    echo "1. 在面板中创建节点实例（协议、端口、传输方式等）"
    echo "2. 点击'部署'按钮，配置将自动推送到此服务器"
    echo "3. 服务将自动启动，用户即可使用"
fi
echo ""
echo -e "${YELLOW}提示: 请确保防火墙已开放相应端口${NC}"
echo "  - SSH: 22 (面板管理必需)"
echo "  - 节点端口: 根据面板中配置的端口开放"
echo ""

# 防火墙自动配置（如果存在）
if command -v ufw >/dev/null 2>&1; then
    echo -e "${YELLOW}检测到 UFW 防火墙，配置基础规则...${NC}"
    ufw allow 22/tcp >/dev/null 2>&1
    echo -e "${GREEN}✓ SSH 端口已开放${NC}"
    echo -e "${YELLOW}  其他端口请根据节点配置手动开放${NC}"
    echo ""
fi

# 时间同步（VMess 协议对时间敏感）
echo -e "${YELLOW}配置时间同步（VMess 协议要求）...${NC}"
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get install -y chrony >/dev/null 2>&1
    systemctl enable chrony >/dev/null 2>&1
    systemctl restart chrony >/dev/null 2>&1
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
    yum install -y chrony >/dev/null 2>&1
    systemctl enable chronyd >/dev/null 2>&1
    systemctl restart chronyd >/dev/null 2>&1
fi
echo -e "${GREEN}✓ 时间同步已配置${NC}"
echo ""

