#!/bin/bash

# PyTunnel-Hub 服务器环境自动安装脚本 (增强版：支持版本选择)
# 用法: curl -fsSL ... | bash -s -- --server-id 1 --api-key xxx --panel-url http://panel.com --xray-version v26.1.23

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 默认参数
SERVER_ID=""
API_KEY=""
PANEL_URL=""
XRAY_VERSION="latest" # 默认最新版

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
        --xray-version)
            XRAY_VERSION="$2" # 例如 v26.1.23
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
    echo "用法: $0 --server-id <id> --api-key <key> --panel-url <url> [--xray-version <version>]"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   PyTunnel-Hub 服务器环境安装脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo "服务器ID: $SERVER_ID"
echo "面板地址: $PANEL_URL"
echo "Xray 版本: $XRAY_VERSION"
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

echo -e "${YELLOW}[1/6] 系统检测: $OS $VERSION${NC}"

# 更新系统基础包
echo -e "${YELLOW}[2/6] 安装基础组件...${NC}"
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt-get update -qq && apt-get install -y curl wget unzip chrony openssl
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
    yum install -y curl wget unzip chrony openssl
fi

# 安装 Xray 内核 (支持版本选择)
echo -e "${YELLOW}[3/6] 安装 Xray 内核 ($XRAY_VERSION)...${NC}"
if [ "$XRAY_VERSION" = "latest" ]; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
else
    # 安装指定版本，例如 v26.1.23
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version "$XRAY_VERSION"
fi

# 安装 Hysteria2 内核
echo -e "${YELLOW}[4/6] 安装 Hysteria2 内核...${NC}"
if ! command -v hysteria >/dev/null 2>&1; then
    bash <(curl -fsSL https://get.hy2.sh/)
fi

# 创建初始配置并建立路径映射
echo -e "${YELLOW}[5/6] 正在初始化 API 闭环配置...${NC}"
mkdir -p /etc/xray /usr/local/etc/xray
mkdir -p /etc/hysteria /usr/local/etc/hysteria

# 写入适配新版 Xray 的 API 闭环配置 (无 api-outbound，依赖内部路由)
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "stats": {},
  "api": {
    "tag": "api",
    "services": ["HandlerService", "StatsService", "LoggerService"]
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api-inbound"
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "blocked" }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "inboundTag": ["api-inbound"],
        "outboundTag": "api"
      }
    ]
  }
}
EOF

# 路径映射
ln -sf /usr/local/etc/xray/config.json /etc/xray/config.json

# Hysteria2 配置
cat > /etc/hysteria/config.yaml <<EOF
listen: :443
tls:
  cert: /etc/hysteria/cert.crt
  key: /etc/hysteria/cert.key
auth:
  type: http
  http:
    url: ${PANEL_URL}/api/traffic/auth
trafficStats:
  listen: 127.0.0.1:4444 
  secret: "${API_KEY}"
EOF
ln -sf /etc/hysteria/config.yaml /usr/local/etc/hysteria/config.yaml

# 生成自签名证书
if [ ! -f /etc/hysteria/cert.crt ]; then
    openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/hysteria/cert.key \
        -out /etc/hysteria/cert.crt -days 3650 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com" >/dev/null 2>&1
fi

# 优化 Systemd
sed -i 's/^User=nobody/User=root/' /etc/systemd/system/xray.service 2>/dev/null || true
systemctl daemon-reload
systemctl enable xray hysteria-server >/dev/null 2>&1 || true

# 自动通知面板同步
echo -e "${YELLOW}[6/6] 正在通知面板推送配置...${NC}"
curl -X POST "${PANEL_URL}/api/servers/${SERVER_ID}/sync" \
     -H "X-Node-API-Key: ${API_KEY}" \
     -H "Content-Type: application/json" -s > /dev/null || true

# 配置时间同步
systemctl enable chrony >/dev/null 2>&1 || true
systemctl restart chrony >/dev/null 2>&1 || true

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   安装完成！API 端口: 10085${NC}"
echo -e "${GREEN}========================================${NC}"
