#!/bin/bash

# PyTunnel-Hub 服务器环境自动安装脚本 (增强版：支持自动卸载与版本重装)
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
    echo -e "${RED}错误: 缺少必需参数${NC}"
    exit 1
fi

# --- 卸载/清理函数 ---
uninstall_old_installation() {
    echo -e "${YELLOW}[-] 检测到旧版本，正在执行自动卸载/清理...${NC}"
    
    # 停止服务
    systemctl stop xray hysteria-server >/dev/null 2>&1 || true
    systemctl disable xray hysteria-server >/dev/null 2>&1 || true
    
    # 使用 Xray 官方脚本尝试卸载 (如果存在)
    if [ -f "/usr/local/bin/xray" ]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove >/dev/null 2>&1 || true
    fi

    # 强制清理遗留文件
    rm -rf /usr/local/bin/xray /usr/local/share/xray /etc/systemd/system/xray.service
    rm -rf /usr/local/bin/hysteria /etc/systemd/system/hysteria-server.service
    
    # 备份旧配置 (防止误删)
    if [ -d "/etc/xray" ]; then
        mv /etc/xray /etc/xray_backup_$(date +%s) >/dev/null 2>&1 || true
    fi
    
    echo -e "${GREEN}[+] 旧版本清理完成。${NC}"
}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    PyTunnel-Hub 环境重装/安装脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 1. 系统环境与权限检查
if [ "$EUID" -ne 0 ]; then echo -e "${RED}请使用 root 运行${NC}"; exit 1; fi

# 2. 自动检测并处理旧安装
if [ -f "/usr/local/bin/xray" ] || [ -f "/usr/local/bin/hysteria" ]; then
    uninstall_old_installation
fi

# 3. 系统组件安装
echo -e "${YELLOW}[1/5] 安装基础组件...${NC}"
apt-get update -qq && apt-get install -y curl wget unzip chrony openssl || yum install -y curl wget unzip chrony openssl

# 4. 安装选定的 Xray 版本
echo -e "${YELLOW}[2/5] 安装 Xray 内核 ($XRAY_VERSION)...${NC}"
if [ "$XRAY_VERSION" = "latest" ]; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
else
    # 明确安装指定版本
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version "$XRAY_VERSION"
fi

# 5. 安装 Hysteria2
echo -e "${YELLOW}[3/5] 安装 Hysteria2...${NC}"
bash <(curl -fsSL https://get.hy2.sh/)

# 6. 配置初始化
echo -e "${YELLOW}[4/5] 写入 API 闭环配置...${NC}"
mkdir -p /etc/xray /etc/hysteria

# 写入 Xray 配置 (适配 v26.x 及其严苛的 API 规则)
cat > /etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "stats": {},
  "api": {
    "tag": "api",
    "services": ["HandlerService", "StatsService"]
  },
  "policy": {
    "levels": { "0": { "statsUserUplink": true, "statsUserDownlink": true } },
    "system": { "statsInboundUplink": true, "statsInboundDownlink": true }
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
      { "type": "field", "inboundTag": ["api-inbound"], "outboundTag": "api" }
    ]
  }
}
EOF

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

# 生成自签名证书
openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/hysteria/cert.key \
    -out /etc/hysteria/cert.crt -days 3650 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com" >/dev/null 2>&1

# 7. 服务启动与优化
sed -i 's/^User=nobody/User=root/' /etc/systemd/system/xray.service 2>/dev/null || true
systemctl daemon-reload
systemctl enable xray hysteria-server
systemctl restart xray hysteria-server chrony

# 8. 通知面板
echo -e "${YELLOW}[5/5] 通知面板同步配置...${NC}"
curl -X POST "${PANEL_URL}/api/servers/${SERVER_ID}/sync" \
     -H "X-Node-API-Key: ${API_KEY}" \
     -H "Content-Type: application/json" -s > /dev/null || true

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    安装完成！版本: $XRAY_VERSION${NC}"
echo -e "${GREEN}    API 端口: 10085 | 状态: 运行中${NC}"
echo -e "${GREEN}========================================${NC}"
