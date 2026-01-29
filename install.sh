#!/bin/bash

# PyTunnel-Hub 服务器环境自动安装脚本 (极致适配版)
# 功能：1. 自动清理旧环境 2. 部署 Xray API 3. 配置 Level 99 黑洞路由 4. 路径标准化
# 用法(安装): curl -fsSL ... | bash -s -- --server-id 1 --api-key xxx --panel-url http://panel.com --xray-version v26.1.23
# 用法(卸载): curl -fsSL ... | bash -s -- --uninstall

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
UNINSTALL_MODE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-id) SERVER_ID="$2"; shift 2 ;;
        --api-key) API_KEY="$2"; shift 2 ;;
        --panel-url) PANEL_URL="$2"; shift 2 ;;
        --xray-version) XRAY_VERSION="$2"; shift 2 ;;
        --uninstall) UNINSTALL_MODE=true; shift ;;
        *) echo -e "${RED}未知参数: $1${NC}"; exit 1 ;;
    esac
done

# ==================== 卸载模式 ====================
if [ "$UNINSTALL_MODE" = "true" ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    PyTunnel-Hub 环境卸载脚本${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    echo -e "${YELLOW}[1/4] 停止服务...${NC}"
    systemctl stop xray hysteria-server 2>/dev/null || true
    systemctl disable xray hysteria-server 2>/dev/null || true
    
    echo -e "${YELLOW}[2/4] 卸载 Xray...${NC}"
    if [ -f "/usr/local/bin/xray" ]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove 2>/dev/null || true
    fi
    rm -f /usr/local/bin/xray /usr/local/share/xray /etc/systemd/system/xray.service 2>/dev/null || true
    
    echo -e "${YELLOW}[3/4] 卸载 Hysteria2...${NC}"
    rm -f /usr/local/bin/hysteria /etc/systemd/system/hysteria-server.service 2>/dev/null || true
    
    echo -e "${YELLOW}[4/4] 清理配置文件和数据...${NC}"
    rm -rf /etc/xray 2>/dev/null || true
    rm -rf /etc/hysteria 2>/dev/null || true
    rm -rf /usr/local/etc/xray 2>/dev/null || true
    rm -f /usr/local/bin/xray 2>/dev/null || true
    
    systemctl daemon-reload
    
    echo -e "${GREEN}[+] 卸载完成！所有服务已停止，配置文件已清理。${NC}"
    exit 0
fi

# ==================== 安装模式 ====================
if [ -z "$SERVER_ID" ] || [ -z "$API_KEY" ] || [ -z "$PANEL_URL" ]; then
    echo -e "${RED}错误: 缺少必需参数 (--server-id, --api-key, --panel-url)${NC}"
    exit 1
fi

# --- 卸载/清理函数 ---
uninstall_old_installation() {
    echo -e "${YELLOW}[-] 检测到旧版本，正在执行自动卸载/清理...${NC}"
    systemctl stop xray hysteria-server >/dev/null 2>&1 || true
    systemctl disable xray hysteria-server >/dev/null 2>&1 || true
    
    if [ -f "/usr/local/bin/xray" ]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove >/dev/null 2>&1 || true
    fi

    rm -rf /usr/local/bin/xray /usr/local/share/xray /etc/systemd/system/xray.service
    rm -rf /usr/local/bin/hysteria /etc/systemd/system/hysteria-server.service
    
    if [ -d "/etc/xray" ]; then
        mv /etc/xray /etc/xray_backup_$(date +%s) >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}[+] 旧版本清理完成。${NC}"
}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    PyTunnel-Hub 环境重装/安装脚本${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$EUID" -ne 0 ]; then echo -e "${RED}请使用 root 运行${NC}"; exit 1; fi

if [ -f "/usr/local/bin/xray" ] || [ -f "/usr/local/bin/hysteria" ]; then
    uninstall_old_installation
fi

echo -e "${YELLOW}[1/5] 安装基础组件...${NC}"
apt-get update -qq && apt-get install -y curl wget unzip chrony openssl || yum install -y curl wget unzip chrony openssl

echo -e "${YELLOW}[2/5] 安装 Xray 内核 ($XRAY_VERSION)...${NC}"
if [ "$XRAY_VERSION" = "latest" ]; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
else
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version "$XRAY_VERSION"
fi

echo -e "${YELLOW}[3/5] 安装 Hysteria2...${NC}"
bash <(curl -fsSL https://get.hy2.sh/)

echo -e "${YELLOW}[4/5] 写入 API 闭环配置与标准化路径...${NC}"
mkdir -p /usr/local/etc/xray
mkdir -p /etc/xray
mkdir -p /etc/hysteria

# 写入 Xray 配置 (适配 API 闭环与 Level 99 黑洞)
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "api": {
    "tag": "api-service",
    "services": ["HandlerService", "StatsService"]
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true,
        "connIdle": 300
      },
      "99": {
        "handshake": 0,
        "connIdle": 0,
        "bufferSize": 0
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
      "port": 8080,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api-inbound"
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "blocked" },
    {
      "protocol": "freedom",
      "tag": "api-service",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["api-inbound"],
        "outboundTag": "api-service"
      },
      {
        "type": "field",
        "userLevel": 99,
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

# 建立软链接
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

# 生成自签名证书 (供 Xray 与 Hy2 共用)
openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/hysteria/cert.key \
    -out /etc/hysteria/cert.crt -days 3650 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=txrui.top" >/dev/null 2>&1

echo -e "${YELLOW}[5/5] 启动服务并优化运行环境...${NC}"

# 确保 Xray 有权限读取证书
if [ -f "/etc/systemd/system/xray.service" ]; then
    sed -i 's/^User=nobody/User=root/' /etc/systemd/system/xray.service
fi

systemctl daemon-reload
systemctl enable xray hysteria-server
systemctl restart xray hysteria-server chrony

# 通知面板同步
curl -X POST "${PANEL_URL}/api/servers/${SERVER_ID}/sync" \
     -H "X-Node-API-Key: ${API_KEY}" \
     -H "Content-Type: application/json" -s > /dev/null || true

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    安装完成！版本: $XRAY_VERSION${NC}"
echo -e "${GREEN}    API 端口: 8080 (127.0.0.1)${NC}"
echo -e "${GREEN}    路径: /usr/local/etc/xray/config.json${NC}"
echo -e "${GREEN}    黑洞策略: 已激活 (Level 99)${NC}"
echo -e "${GREEN}========================================${NC}"
