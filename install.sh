#!/bin/bash

# PyTunnel-Hub 服务器环境自动安装脚本 (极致适配完整版)
# 功能：
# 1. 自动安装 Xray & Hysteria2
# 2. 部署 Level 99 黑洞路由规则 (实现秒级断网)
# 3. 规范化路径：/usr/local/etc/xray/config.json -> /etc/xray/config.json
# 4. 自动生成自签名证书并适配双协议

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
XRAY_VERSION="latest"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-id) SERVER_ID="$2"; shift 2 ;;
        --api-key) API_KEY="$2"; shift 2 ;;
        --panel-url) PANEL_URL="$2"; shift 2 ;;
        --xray-version) XRAY_VERSION="$2"; shift 2 ;;
        *) echo -e "${RED}未知参数: $1${NC}"; exit 1 ;;
    esac
done

if [ -z "$SERVER_ID" ] || [ -z "$API_KEY" ] || [ -z "$PANEL_URL" ]; then
    echo -e "${RED}错误: 缺少必需参数 (--server-id, --api-key, --panel-url)${NC}"
    exit 1
fi

# --- 卸载/清理函数 ---
uninstall_old_installation() {
    echo -e "${YELLOW}[-] 检测到旧版本，执行清理...${NC}"
    systemctl stop xray hysteria-server >/dev/null 2>&1 || true
    systemctl disable xray hysteria-server >/dev/null 2>&1 || true
    if [ -f "/usr/local/bin/xray" ]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove >/dev/null 2>&1 || true
    fi
    rm -rf /usr/local/bin/xray /usr/local/share/xray /etc/systemd/system/xray.service
    rm -rf /usr/local/bin/hysteria /etc/systemd/system/hysteria-server.service
    echo -e "${GREEN}[+] 旧版本清理完成。${NC}"
}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    PyTunnel-Hub 环境极致适配版安装${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$EUID" -ne 0 ]; then echo -e "${RED}请使用 root 运行${NC}"; exit 1; fi

uninstall_old_installation

echo -e "${YELLOW}[1/5] 安装基础组件...${NC}"
apt-get update -qq && apt-get install -y curl wget unzip chrony openssl || yum install -y curl wget unzip chrony openssl

echo -e "${YELLOW}[2/5] 安装 Xray 内核 ($XRAY_VERSION)...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install ${XRAY_VERSION:+--version $XRAY_VERSION}

echo -e "${YELLOW}[3/5] 安装 Hysteria2...${NC}"
bash <(curl -fsSL https://get.hy2.sh/)

echo -e "${YELLOW}[4/5] 写入 API 闭环配置与软链接...${NC}"
mkdir -p /usr/local/etc/xray /etc/xray /etc/hysteria

# 1. 自动生成自签名证书 (供 Xray TLS 和 Hysteria2 共用)
openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/hysteria/cert.key \
    -out /etc/hysteria/cert.crt -days 3650 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com" >/dev/null 2>&1

# 2. 写入 Xray 核心配置 (实际路径)
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "stats": {},
  "api": {
    "tag": "api",
    "services": ["HandlerService", "StatsService"]
  },
  "policy": {
    "levels": { 
        "0": { 
            "statsUserUplink": true, 
            "statsUserDownlink": true,
            "connIdle": 300 
        },
        "99": { 
            "statsUserUplink": false, 
            "statsUserDownlink": false,
            "handshake": 0,
            "connIdle": 0 
        }
    },
    "system": { "statsInboundUplink": true, "statsInboundDownlink": true }
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 8080,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api-inbound"
    },
    {
      "port": 8787,
      "protocol": "vmess",
      "tag": "vmess-1",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "wsSettings": { "path": "/" },
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "/etc/hysteria/cert.crt",
            "keyFile": "/etc/hysteria/cert.key"
          }]
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block-out" },
    { "protocol": "freedom", "tag": "api", "settings": {} }
  ],
  "routing": {
    "rules": [
      { "type": "field", "inboundTag": ["api-inbound"], "outboundTag": "api" },
      { "type": "field", "userLevel": 99, "outboundTag": "block-out" },
      { "type": "field", "ip": ["geoip:private"], "outboundTag": "block-out" }
    ]
  }
}
EOF

# 3. 建立软链接
ln -sf /usr/local/etc/xray/config.json /etc/xray/config.json

# 4. Hysteria2 配置
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

echo -e "${YELLOW}[5/5] 启动服务并同步面板...${NC}"
# 修正 Xray Service 以 root 运行以便读取证书和执行 API
if [ -f "/etc/systemd/system/xray.service" ]; then
    sed -i 's/^User=nobody/User=root/' /etc/systemd/system/xray.service
fi

systemctl daemon-reload
systemctl enable xray hysteria-server
systemctl restart xray hysteria-server chrony

# 调用面板同步接口
curl -X POST "${PANEL_URL}/api/servers/${SERVER_ID}/sync" \
     -H "X-Node-API-Key: ${API_KEY}" \
     -H "Content-Type: application/json" -s > /dev/null || true

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    安装完成！配置生效中...${NC}"
echo -e "${GREEN}    Xray 配置: /etc/xray/config.json${NC}"
echo -e "${GREEN}    API 地址: 127.0.0.1:8080${NC}"
echo -e "${GREEN}    黑洞规则: Level 99 已激活${NC}"
echo -e "${GREEN}========================================${NC}"
