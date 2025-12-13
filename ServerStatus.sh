cat << 'EOF' > status_client.sh
#!/bin/bash

SERVER_IP="165.99.43.198"
CLIENT_PATH=$(pwd)/client-linux.py

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
    echo "示例：输入 05 则 ID 为 s05"
    read -p "请输入 ID 数字部分 (默认 04): " USER_NUM
    USER_NUM=${USER_NUM:-04}
    # 自动拼接前缀 s
    USER_ID="s${USER_NUM}"

    echo "正在下载脚本..."
    wget --no-check-certificate -qO client-linux.py 'https://raw.githubusercontent.com/cppla/ServerStatus/master/clients/client-linux.py'
    
    echo "正在清理旧进程..."
    pkill -f client-linux.py >/dev/null 2>&1

    echo "正在启动客户端..."
    nohup python3 "${CLIENT_PATH}" SERVER=${SERVER_IP} USER=${USER_ID} >/dev/null 2>&1 &
    
    echo "正在设置开机自启..."
    (crontab -l 2>/dev/null | grep -v "client-linux.py"; echo "@reboot /usr/bin/python3 ${CLIENT_PATH} SERVER=${SERVER_IP} USER=${USER_ID} >/dev/null 2>&1 &") | crontab -
    
    echo "✅ 安装成功！最终 ID 为: ${USER_ID}"
}

uninstall_client() {
    echo "正在停止进程..."
    pkill -f client-linux.py >/dev/null 2>&1
    echo "正在移除开机自启..."
    crontab -l 2>/dev/null | grep -v "client-linux.py" | crontab -
    echo "正在删除脚本文件..."
    rm -f client-linux.py
    echo "✅ 卸载完成！"
}

check_status() {
    echo "-----------------------------------------------"
    echo "🔍 进程状态："
    # 使用 grep -v grep 过滤掉搜索进程本身
    if ps -ef | grep "client-linux.py" | grep -v grep > /dev/null; then
        ps -ef | grep "client-linux.py" | grep -v grep
    else
        echo "❌ 客户端未在运行"
    fi
    echo ""
    echo "🔍 开机自启任务："
    crontab -l | grep "client-linux.py" || echo "❌ 未发现自启任务"
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
