cat << 'EOF' > status_client.sh
#!/bin/bash

SERVER_IP="165.99.43.198"
CLIENT_PATH=$(pwd)/client-linux.py

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检测并安装 Python
check_python() {
    if command -v python3 >/dev/null 2>&1; then
        echo -e "${GREEN}检测到 Python3 已安装${NC}"
    else
        echo -e "${YELLOW}未检测到 Python3，正在尝试自动安装...${NC}"
        if [ -f /etc/debian_version ]; then
            apt-get update && apt-get install -y python3
        elif [ -f /etc/redhat-release ]; then
            yum install -y python3
        else
            echo -e "${RED}无法自动安装 Python3，请手动安装后重试。${NC}"
            exit 1
        fi
        
        # 再次检查
        if ! command -v python3 >/dev/null 2>&1; then
            echo -e "${RED}Python3 安装失败，请检查网络或源设置。${NC}"
            exit 1
        fi
    fi
}

show_menu() {
    echo "-----------------------------------------------"
    echo "   ServerStatus 客户端管理工具 (ID前缀: s)"
    echo "-----------------------------------------------"
    echo "1. 安装/更新 客户端"
    echo "2. 彻底卸载 客户端"
    echo "3. 查看运行状态"
    echo "0. 退出"
    echo "-----------------------------------------------"
    read -p "请选择操作 [0-3]: " choice
}

install_client() {
    # 执行 Python 环境检查
    check_python

    echo "示例：输入 05 则 ID 为 s05"
    read -p "请输入 ID 数字部分 (默认 04): " USER_NUM
    USER_NUM=${USER_NUM:-04}
    USER_ID="s${USER_NUM}"

    echo "正在下载脚本..."
    wget --no-check-certificate -qO client-linux.py 'https://raw.githubusercontent.com/cppla/ServerStatus/master/clients/client-linux.py'
    
    if [ ! -f "client-linux.py" ]; then
        echo -e "${RED}脚本下载失败，请检查网络连接${NC}"
        return
    fi

    echo "正在清理旧进程..."
    pkill -f client-linux.py >/dev/null 2>&1

    echo "正在启动客户端..."
    # 显式使用 python3 绝对路径
    PY_PATH=$(command -v python3)
    nohup ${PY_PATH} "${CLIENT_PATH}" SERVER=${SERVER_IP} USER=${USER_ID} >/dev/null 2>&1 &
    
    echo "正在设置开机自启..."
    (crontab -l 2>/dev/null | grep -v "client-linux.py"; echo "@reboot ${PY_PATH} ${CLIENT_PATH} SERVER=${SERVER_IP} USER=${USER_ID} >/dev/null 2>&1 &") | crontab -
    
    echo -e "${GREEN}✅ 安装成功！最终 ID 为: ${USER_ID}${NC}"
}

uninstall_client() {
    echo "正在停止进程..."
    pkill -f client-linux.py >/dev/null 2>&1
    echo "正在移除开机自启..."
    crontab -l 2>/dev/null | grep -v "client-linux.py" | crontab -
    echo "正在删除脚本文件..."
    rm -f client-linux.py
    echo -e "${GREEN}✅ 卸载完成！${NC}"
}

check_status() {
    echo "-----------------------------------------------"
    echo -e "${YELLOW}🔍 进程状态：${NC}"
    if ps -ef | grep "client-linux.py" | grep -v grep > /dev/null; then
        ps -ef | grep "client-linux.py" | grep -v grep
    else
        echo -e "${RED}❌ 客户端未在运行${NC}"
    fi
    echo ""
    echo -e "${YELLOW}🔍 开机自启任务：${NC}"
    crontab -l | grep "client-linux.py" || echo -e "${RED}❌ 未发现自启任务${NC}"
    echo "-----------------------------------------------"
}

while true; do
    show_menu
    case $choice in
        1) install_client ;;
        2) uninstall_client ;;
        3) check_status ;;
        0) exit 0 ;;
        *) echo "无效选项，请重新选择" ;;
    esac
done
EOF

chmod +x status_client.sh && ./status_client.sh
