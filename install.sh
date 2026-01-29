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
    rm -f /usr/local/bin/xray /usr/local/share/xray /etc/systemd/system/xray.service /lib/systemd/system/xray.service 2>/dev/null || true
    
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

    rm -rf /usr/local/bin/xray /usr/local/share/xray
    rm -f /etc/systemd/system/xray.service /lib/systemd/system/xray.service
    rm -f /usr/local/bin/hysteria /etc/systemd/system/hysteria-server.service
    
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

# 写入 Xray 配置 (采用 3x-ui 的 tunnel 协议架构，极大提升 API 稳定性和隐蔽性)
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning", "access": "none" },
  "api": {
    "tag": "api",
    "services": ["HandlerService", "LoggerService", "StatsService"]
  },
  "stats": {},
  "metrics": {
    "tag": "metrics_out",
    "listen": "127.0.0.1:11111"
  },
  "policy": {
    "levels": {
      "0": { "statsUserUplink": true, "statsUserDownlink": true, "connIdle": 300 }
    },
    "system": { "statsInboundUplink": true, "statsInboundDownlink": true }
  },
  "inbounds": [
    {
      "tag": "api",
      "listen": "127.0.0.1",
      "port": 62789,
      "protocol": "tunnel",
      "settings": { "address": "127.0.0.1" }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom", "settings": { "domainStrategy": "AsIs" } },
    { "tag": "blocked", "protocol": "blackhole", "settings": {} }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "type": "field", "inboundTag": ["api"], "outboundTag": "api" },
      { "type": "field", "ip": ["geoip:private"], "outboundTag": "blocked" },
      { "type": "field", "protocol": ["bittorrent"], "outboundTag": "blocked" }
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

# [优化1] 修正证书权限，确保 Xray 和 Hy2 都能读取
chmod 644 /etc/hysteria/cert.key /etc/hysteria/cert.crt

# [优化2] 自动查找并修正 Xray 服务权限 (兼容不同发行版)
SERVICE_PATH=$(systemctl show -p FragmentPath xray 2>/dev/null | cut -d= -f2)
if [ -n "$SERVICE_PATH" ] && [ -f "$SERVICE_PATH" ]; then
    echo -e "${YELLOW}[*] 修正服务权限: $SERVICE_PATH${NC}"
    sed -i 's/^User=nobody/User=root/' "$SERVICE_PATH"
elif [ -f "/etc/systemd/system/xray.service" ]; then
    # 兼容旧逻辑
    sed -i 's/^User=nobody/User=root/' /etc/systemd/system/xray.service
fi

systemctl daemon-reload
systemctl enable xray hysteria-server chrony
systemctl restart xray hysteria-server chrony

# [优化3] 验证安装并等待 API 就绪
echo -e "${YELLOW}[验证] 检查服务状态...${NC}"
sleep 3

# 检查 Xray
if systemctl is-active --quiet xray; then
    echo -e "${GREEN}[✓] Xray 服务运行正常${NC}"
    XRAY_VERSION_INSTALLED=$(xray version | head -n 1)
    echo -e "${GREEN}[✓] Xray 版本: $XRAY_VERSION_INSTALLED${NC}"
else
    echo -e "${RED}[✗] Xray 服务启动失败${NC}"
    systemctl status xray --no-pager || true
fi

# 检查 Hysteria2
if systemctl is-active --quiet hysteria-server; then
    echo -e "${GREEN}[✓] Hysteria2 服务运行正常${NC}"
else
    echo -e "${RED}[✗] Hysteria2 服务启动失败${NC}"
    systemctl status hysteria-server --no-pager || true
fi

# [优化4] 通知面板同步 (带超时和重试)
echo -e "${YELLOW}[同步] 通知面板同步配置...${NC}"
curl -X POST "${PANEL_URL}/api/servers/${SERVER_ID}/sync" \
     -H "X-Node-API-Key: ${API_KEY}" \
     -H "Content-Type: application/json" \
     -m 10 --retry 3 --retry-delay 2 \
     -s > /dev/null || echo -e "${YELLOW}[!] 面板同步超时，Xray 将在 1-2 秒后自动就绪${NC}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    安装完成！版本: $XRAY_VERSION${NC}"
echo -e "${GREEN}    API 端口: 62789 (127.0.0.1)${NC}"
echo -e "${GREEN}    Hysteria2: 443${NC}"
echo -e "${GREEN}    配置文件: /usr/local/etc/xray/config.json${NC}"
echo -e "${GREEN}========================================${NC}"
